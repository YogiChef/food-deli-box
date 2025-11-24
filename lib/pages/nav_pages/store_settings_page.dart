// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/controllers/vendor_controller.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/widgets/button_widget.dart';
import 'package:vendor_box/widgets/time_selector_widget.dart';

class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({super.key});

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  final VendorController _vendorController = VendorController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, String?>> hours =
      {}; // แก้: Type Map<String, Map<String, String?>> เพื่อ allow null (compile ผ่าน)
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  String? _currentStatus;

  @override
  void initState() {
    super.initState();
  }

  void _updateCurrentStatus() {
    final now = DateTime.now();
    final dayKey = _getDayKey(now.weekday);
    final dayEntry = hours[dayKey];
    if (dayEntry == null ||
        (dayEntry['open'] == null && dayEntry['close'] == null)) {
      _currentStatus = 'Always Open';
      return;
    }
    final openStr = dayEntry['open'];
    final closeStr = dayEntry['close'];
    if (openStr == null || closeStr == null) {
      _currentStatus = 'Partial Hours Set';
      return;
    }
    try {
      final openParts = openStr.split(':');
      final closeParts = closeStr.split(':');
      final openTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(openParts[0]),
        int.parse(openParts[1]),
      );
      final closeTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(closeParts[0]),
        int.parse(closeParts[1]),
      );
      setState(() {
        _currentStatus = now.isAfter(openTime) && now.isBefore(closeTime)
            ? 'Open Now'
            : 'Closed';
      });
    } catch (e) {
      _currentStatus = 'Invalid Hours';
    }
  }

  String _getDayKey(int weekday) {
    const days = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];
    return days[(weekday % 7) - 1 < 0 ? 6 : (weekday % 7) - 1];
  }

  void _onSaveTime(String day, String? open, String? close) {
    final lowerDay = day.toLowerCase();
    final Map<String, String?> dayEntry =
        hours[lowerDay] ?? <String, String?>{'open': null, 'close': null};

    bool hasChange = false;

    if (open != null) {
      dayEntry['open'] = open;
      hasChange = true;
      print('Updated open for $day: $open');
    }
    if (close != null) {
      dayEntry['close'] = close;
      hasChange = true;
      print('Updated close for $day: $close');
    }

    if (hasChange) {
      setState(() {
        hours[lowerDay] = dayEntry;
      });
      _updateCurrentStatus();
    } else if (dayEntry['open'] == null && dayEntry['close'] == null) {
      setState(() {
        hours.remove(lowerDay);
      });
    }

    // Validation (skip ถ้า null)
    if (dayEntry['open'] != null && dayEntry['close'] != null) {
      final openStr = dayEntry['open']!;
      final closeStr = dayEntry['close']!;
      if (openStr.contains(':') && closeStr.contains(':')) {
        try {
          final openHour = int.parse(openStr.split(':')[0]);
          final closeHour = int.parse(closeStr.split(':')[0]);
          if (closeHour <= openHour) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('คำเตือน: เวลาปิดควรหลังเวลาเปิด'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          print('Validation error: $e');
        }
      }
    }
  }

  Future<void> _saveHours() async {
    if (hours.values
        .where((entry) => entry['open'] != null || entry['close'] != null)
        .isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกเวลาอย่างน้อยหนึ่งวัน')),
      );
      return;
    }
    try {
      await _vendorController.saveStoreHours(
        hours,
      ); // Save Map<String, Map<String, String?>> (Firestore handle null OK)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกเวลาสำเร็จ! สถานะปัจจุบัน: $_currentStatus'),
        ),
      );
    } catch (e) {
      print('Save error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;
    final vendorStream = _firestore.collection('vendors').doc(uid).snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ตั้งค่าเวลาร้านค้า',
          style: styles(fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: vendorStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No vendor data'));
          }

          final vendorData = snapshot.data!.data() as Map<String, dynamic>;
          // แก้ไขหลัก: โหลดข้อมูลเฉพาะตอนแรก (hours.isEmpty) เพื่อไม่ให้ overwrite การเปลี่ยนแปลง local ทุกครั้งที่ rebuild
          if (hours.isEmpty) {
            final Map<String, Map<String, String?>> loadedHours =
                Map<String, Map<String, String?>>.from(
                  (vendorData['storeHours'] as Map<String, dynamic>?)?.map(
                        (k, v) => MapEntry(
                          k,
                          Map<String, String?>.from(v as Map<String, dynamic>),
                        ),
                      ) ??
                      {},
                );
            hours = loadedHours;
            _updateCurrentStatus();
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... Current status card เดิม
                SizedBox(height: 20.h),
                Text(
                  'เลือกเวลาทำการรายวัน',
                  style: styles(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12.h),
                // แก้: Key เปลี่ยนเมื่อ hours update เพื่อ force rebuild child (แสดง props ใหม่)
                ..._days.map(
                  (day) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: TimeSelectorWidget(
                      key: ValueKey(
                        '${day}-${hours[day.toLowerCase()]?['open']}-${hours[day.toLowerCase()]?['close']}',
                      ), // แก้: Key จาก hours เพื่อ rebuild เมื่อ props เปลี่ยน
                      dayLabel: day,
                      onSave: _onSaveTime,
                      currentOpen: hours[day.toLowerCase()]?['open'],
                      currentClose: hours[day.toLowerCase()]?['close'],
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                BottonWidget(
                  label: 'บันทึกการเปลี่ยนแปลง',
                  icon: Icons.save,
                  press: _saveHours,
                  color: mainColor,
                  height: 50.h,
                ),
                SizedBox(height: 20.h),
              ],
            ),
          );
        },
      ),
    );
  }
}
