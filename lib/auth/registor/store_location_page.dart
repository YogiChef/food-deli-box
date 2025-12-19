// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // NEW: สำหรับ smooth gesture
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/pages/main_vendor_page.dart';

class StoreLocationPage extends StatefulWidget {
  const StoreLocationPage({super.key});

  @override
  State<StoreLocationPage> createState() => _StoreLocationPageState();
}

class _StoreLocationPageState extends State<StoreLocationPage> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(13.7563, 100.5018); // Default Bangkok
  final Set<Marker> _markers = <Marker>{};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addMarker(_currentPosition);
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // print('DEBUG: Starting _getCurrentLocation...'); // Comment เพื่อลด lag
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('เปิด Location Services ใน Settings');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('อนุญาต Location ใน Settings (Allow all the time)');
      }

      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          ).timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw Exception('Timeout – ลองกดปุ่มอีกครั้ง');
            },
          );

      // print('DEBUG: Position got: ${position.latitude}, ${position.longitude}'); // Comment

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _addMarker(_currentPosition);
        _isLoading = false;
      });
    } catch (e) {
      // print('DEBUG: Location error: $e'); // Comment
      setState(() {
        _error =
            'ไม่พบตำแหน่งจริง: $e\n(ตรวจ Settings > Permissions > Location > Allow all the time)';
        _isLoading = false;
      });
    }
  }

  void _addMarker(LatLng position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('store'),
          position: position,
          draggable: true,
          infoWindow: const InfoWindow(
            title: 'ร้านของคุณ',
            snippet: 'ลากเพื่อย้าย',
          ),
          onDragEnd: (LatLng newPos) {
            setState(() => _currentPosition = newPos);
          },
        ),
      );
    });

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 16.0));
  }

  void _onMapTap(LatLng position) {
    _currentPosition = position;
    _addMarker(position);
  }

  Future<void> _saveLocation() async {
    if (auth.currentUser == null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เข้าสู่ระบบก่อน')));
      return;
    }

    final uid = auth.currentUser!.uid;
    final location = GeoPoint(
      _currentPosition.latitude,
      _currentPosition.longitude,
    );

    try {
      await firestore.collection('vendors').doc(uid).update({
        'location': location,
      });
      // FIXED: Show SnackBar ก่อน navigate (prevent unmounted)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกแล้ว!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      // Delay เล็กน้อยเพื่อ SnackBar show
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainVendorPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกไม่ได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ปักหมุดร้านค้า'),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition,
                      zoom: 15.0,
                    ),
                    markers: _markers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _onMapTap,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: MapType.normal,
                    zoomControlsEnabled: true,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    liteModeEnabled: false,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      // NEW: Smooth touch
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    onCameraIdle: () {}, // ลบ print เพื่อลด lag
                  ),
          ),
          if (_error != null)
            Positioned(
              top: 100.h,
              left: 16.w,
              right: 16.w,
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(_error!, style: TextStyle(fontSize: 12.sp)),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _getCurrentLocation();
                      },
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
          // Positioned(
          //   bottom: 120.h,
          //   left: 16.w,
          //   right: 16.w,
          //   child: Container(
          //     padding: EdgeInsets.all(12.w),
          //     decoration: BoxDecoration(
          //       color: Colors.blue.shade100,
          //       borderRadius: BorderRadius.circular(8.r),
          //     ),
          //     child: const Row(
          //       children: [
          //         Icon(Icons.touch_app, color: Colors.blue),
          //         SizedBox(width: 8),
          //         // Expanded(child: Text('แตะแผนที่เพื่อปักหมุด, ลากเพื่อย้าย')),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16.w),
        child: ElevatedButton.icon(
          onPressed: _saveLocation,
          icon: const Icon(Icons.save),
          label: const Text('บันทึกตำแหน่ง'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _getCurrentLocation,
      //   label: const Text('ตำแหน่งปัจจุบัน'),
      //   icon: _isLoading
      //       ? const SizedBox(
      //           child: CircularProgressIndicator(
      //             strokeWidth: 2,
      //             color: Colors.white,
      //           ),
      //         )
      //       : const Icon(Icons.my_location),
      //   tooltip: 'กดเพื่อหาตำแหน่งจริง',
      // ),
    );
  }
}
