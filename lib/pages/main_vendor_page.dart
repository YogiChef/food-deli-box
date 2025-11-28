// ignore_for_file: avoid_print

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vendor_box/auth/landing_page.dart';
import 'package:vendor_box/models/vendor_model.dart';
import 'package:vendor_box/pages/general_upload.dart';
import 'package:vendor_box/pages/nav_pages/eanings_page.dart';
import 'package:vendor_box/pages/nav_pages/edit_page.dart';
import 'package:vendor_box/pages/nav_pages/orders.dart';
import 'package:badges/badges.dart' as badges;
import 'package:vendor_box/pages/nav_pages/store_settings_page.dart';
import 'package:vendor_box/services/sevice.dart';

class MainVendorPage extends StatefulWidget {
  const MainVendorPage({super.key});

  @override
  State<MainVendorPage> createState() => _MainVendorPageState();
}

class _MainVendorPageState extends State<MainVendorPage> {
  final String vendorUid = auth.currentUser!.uid;
  late Stream<QuerySnapshot> _ordersStream;
  Timer? _closeCheckTimer;
  VendorModel? _cachedVendor;

  @override
  void initState() {
    super.initState();
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: vendorUid)
        .where('status', whereIn: ['preparing', 'pending'])
        .snapshots();
  }

  @override
  void dispose() {
    _closeCheckTimer?.cancel();
    super.dispose();
  }

  bool _checkIsOpenNow(VendorModel vendorsModel) {
    bool isOpenNow = true;
    if (vendorsModel.storeHours != null &&
        vendorsModel.storeHours!.isNotEmpty) {
      final now = DateTime.now();
      final dayKey = _getDayKey(now.weekday);
      final dayHours = vendorsModel.storeHours![dayKey];
      if (dayHours != null) {
        if (dayHours['closed'] == true) {
          isOpenNow = false;
        } else {
          try {
            final openParts = (dayHours['open'] as String).split(':');
            final closeParts = (dayHours['close'] as String).split(':');
            final openHour = int.parse(openParts[0]);
            final openMinute = int.parse(openParts[1]);
            final closeHour = int.parse(closeParts[0]);
            final closeMinute = int.parse(closeParts[1]);
            final openTime = DateTime(
              now.year,
              now.month,
              now.day,
              openHour,
              openMinute,
            );
            final closeTime = DateTime(
              now.year,
              now.month,
              now.day,
              closeHour,
              closeMinute,
            );
            isOpenNow = now.isAfter(openTime) && now.isBefore(closeTime);
          } catch (e) {
            // Silent fail, assume open
          }
        }
      }
    }
    return isOpenNow;
  }

  void _startCloseCheckTimer(VendorModel vendorsModel) {
    _cachedVendor = vendorsModel;
    _closeCheckTimer?.cancel();
    _closeCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final isOpenNow = _checkIsOpenNow(_cachedVendor!);
      if (!isOpenNow || _cachedVendor!.temporarilyClosed) {
        timer.cancel();
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
              );
            }
          });
        }
      }
    });
  }

  String _getDayKey(int weekday) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days[weekday - 1];
  }

  int _pageIndex = 0;
  final List<Widget> _page = [
    const EarningPage(),
    const GeneralTab(),
    const EditPage(),
    const OrderPage(),
    const StoreSettingsPage(),
  ];

  Widget _buildMainBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final pendingCount = snapshot.data?.docs.length ?? 0;
        return Scaffold(
          bottomNavigationBar: BottomNavigationBar(
            unselectedItemColor: Colors.grey,
            currentIndex: _pageIndex,
            selectedLabelStyle: GoogleFonts.righteous(fontSize: 16),
            onTap: (value) => setState(() => _pageIndex = value),
            selectedItemColor: mainColor,
            items: [
              BottomNavigationBarItem(
                icon: Icon(
                  _pageIndex == 0 ? IconlyBold.wallet : IconlyLight.wallet,
                ),
                label: 'Earnings',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  _pageIndex == 1 ? IconlyBold.upload : IconlyLight.upload,
                ),
                label: 'Upload',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  _pageIndex == 2 ? IconlyBold.edit : IconlyLight.edit,
                ),
                label: 'Edit',
              ),
              BottomNavigationBarItem(
                icon: badges.Badge(
                  showBadge: pendingCount == 0 ? false : true,
                  badgeContent: Text(
                    pendingCount.toString(),
                    style: styles(color: Colors.white, fontSize: 12),
                  ),
                  child: Icon(
                    _pageIndex == 3 ? IconlyBold.bag2 : IconlyLight.bag2,
                  ),
                ),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  _pageIndex == 4 ? IconlyBold.setting : IconlyLight.setting,
                ),
                label: 'Settings',
              ),
            ],
          ),
          body: _page[_pageIndex],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ใหม่: ใช้ FutureBuilder สำหรับ initial vendor check (เร็วขึ้น, no nested stream)
    return FutureBuilder<DocumentSnapshot>(
      future: firestore
          .collection('vendors')
          .doc(vendorUid)
          .get(), // get() ครั้งเดียว
      builder: (context, vendorSnapshot) {
        if (vendorSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (vendorSnapshot.hasError ||
            !vendorSnapshot.hasData ||
            !vendorSnapshot.data!.exists) {
          _closeCheckTimer?.cancel();
          return const LandingPage();
        }

        final VendorModel vendorsModel = VendorModel.fromJson(
          vendorSnapshot.data!.data() as Map<String, dynamic>,
        );

        // เช็ค temporarilyClosed หรือ !isOpenNow → ไป Landing
        if (vendorsModel.temporarilyClosed ||
            vendorsModel.approved != true ||
            !_checkIsOpenNow(vendorsModel)) {
          _closeCheckTimer?.cancel();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
              );
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ); // Temp
        }

        // ถ้า open: Start timer + แสดง body
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _startCloseCheckTimer(vendorsModel),
        );

        return _buildMainBody(); // Orders Stream แยก (real-time แต่ไม่ nested)
      },
    );
  }
}
