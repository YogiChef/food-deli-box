// ignore_for_file: avoid_print

import 'dart:async'; // ใหม่: สำหรับ Timer
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/models/vendor_model.dart';
import 'package:vendor_box/pages/main_vendor_page.dart';
import 'package:vendor_box/auth/vendor_auth.dart';
import 'package:vendor_box/pages/nav_pages/store_settings_page.dart';
import 'package:vendor_box/services/sevice.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  Timer? _timer; // ใหม่: Timer สำหรับเช็คเวลาอัตโนมัติ
  Timer? _countdownTimer; // ใหม่: Timer สำหรับนับถอยหลัง
  final ValueNotifier<String> _countdownNotifier = ValueNotifier('');

  @override
  void dispose() {
    _timer?.cancel(); // ใหม่: Cancel timer เมื่อ dispose
    _countdownTimer?.cancel();
    _countdownNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        print(
          'Auth snapshot: hasData = ${authSnapshot.hasData}, uid = ${authSnapshot.data?.uid}',
        );
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          print('Waiting for auth...');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          print('No user – Going to VendorAuthPage (Login)');
          _timer?.cancel(); // Cancel ถ้า logout
          _countdownTimer?.cancel();
          return const VendorAuthPage();
        }

        final CollectionReference vendorsStream = firestore.collection(
          'vendors',
        );
        return Scaffold(
          body: StreamBuilder<DocumentSnapshot>(
            stream: vendorsStream.doc(authSnapshot.data!.uid).snapshots(),
            builder: (context, vendorSnapshot) {
              print(
                'Vendor snapshot: hasData = ${vendorSnapshot.hasData}, exists = ${vendorSnapshot.data?.exists}',
              );
              if (vendorSnapshot.hasError) {
                print('Vendor error: ${vendorSnapshot.error}');
                return Center(
                  child: Text('เกิดข้อผิดพลาด: ${vendorSnapshot.error}'),
                );
              }

              if (vendorSnapshot.connectionState == ConnectionState.waiting) {
                print('Waiting for vendor doc...');
                return const Center(child: CircularProgressIndicator());
              }

              if (!vendorSnapshot.hasData || !vendorSnapshot.data!.exists) {
                print('No vendor doc – Going to VendorAuthPage (Login/Setup)');
                _timer?.cancel();
                _countdownTimer?.cancel();
                return const VendorAuthPage();
              }

              final VendorModel vendorsModel = VendorModel.fromJson(
                vendorSnapshot.data!.data() as Map<String, dynamic>,
              );

              // เช็ค temporarilyClosed ก่อน (override ทุกอย่าง)
              if (vendorsModel.temporarilyClosed) {
                print('Temporarily closed – Showing closed UI');
                // ไม่ start timer ที่นี่ เพราะ StreamBuilder จะ handle เมื่อ doc เปลี่ยน
                _timer?.cancel();
                _countdownTimer?.cancel();
                _resetCountdown(); // Clear countdown
                return _buildClosedUI(
                  context,
                  'ปิดชั่วคราว',
                  Icons.block,
                  Colors.red,
                  vendorsModel,
                );
              }

              // เช็ค store hours
              bool isOpenNow = _checkIsOpenNow(
                vendorsModel,
              ); // ใหม่: แยกฟังก์ชันเช็ค

              if (vendorsModel.approved == true) {
                print('Approved – isOpenNow = $isOpenNow');
                if (!isOpenNow) {
                  print('Not open now – Showing closed UI + Starting timers');
                  _startAutoCheckTimer(
                    vendorsModel,
                  ); // ใหม่: เริ่ม timer ถ้าปิดวันนี้
                  _startCountdownTimer(
                    vendorsModel,
                  ); // ใหม่: เริ่ม countdown เฉพาะที่นี่ (ครั้งเดียว)
                  return _buildClosedUI(
                    context,
                    'วันนี้ร้านปิด',
                    Icons.schedule,
                    Colors.orange,
                    vendorsModel,
                  );
                }
                _timer?.cancel(); // Cancel timer ถ้าเปิดแล้ว
                _countdownTimer?.cancel();
                _resetCountdown();
                print('Open now – Going to MainVendorPage');
                return const MainVendorPage();
              } else {
                print('Not approved – Showing pending UI');
                _timer?.cancel();
                _countdownTimer?.cancel();
                _resetCountdown();
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.network(
                          vendorsModel.image.isNotEmpty
                              ? vendorsModel.image
                              : 'https://via.placeholder.com/90',
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error, size: 90),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        vendorsModel.bussinessName,
                        style: styles(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'ใบสมัครของคุณได้ถูกส่งไปยังผู้ดูแลร้านค้าแล้ว\nผู้ดูแลจะติดต่อกลับในเร็วๆ นี้',
                        textAlign: TextAlign.center,
                        style: styles(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade200,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () async {
                          await auth.signOut();
                          _timer?.cancel();
                          _countdownTimer?.cancel();
                        },
                        child: Text(
                          'ออกจากระบบ',
                          style: styles(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.cyan.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  // ใหม่: แยกฟังก์ชันเช็ค isOpenNow (เพื่อ reuse ใน timer)
  bool _checkIsOpenNow(VendorModel vendorsModel) {
    bool isOpenNow = true;
    if (vendorsModel.storeHours != null &&
        vendorsModel.storeHours!.isNotEmpty) {
      final now = DateTime.now();
      final dayKey = _getDayKey(now.weekday);
      print('Current dayKey: $dayKey (weekday=${now.weekday})');
      final dayHours = vendorsModel.storeHours![dayKey];
      print('Day hours: $dayHours');
      if (dayHours != null) {
        if (dayHours['closed'] == true) {
          isOpenNow = false;
          print('Day closed=true → isOpenNow=false');
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
            print(
              'Parsed times: open=$openTime, close=$closeTime, isOpenNow=$isOpenNow',
            );
          } catch (e) {
            print('Error parsing store hours: $e');
          }
        }
      }
    }
    return isOpenNow;
  }

  // ใหม่: เริ่ม Timer เช็คทุก 30 วินาที ถ้าถึงเวลาเปิด → setState() เพื่อ rebuild และเข้า Main
  void _startAutoCheckTimer(VendorModel vendorsModel) {
    _timer?.cancel(); // Cancel timer เก่า
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      print('Auto-check timer tick: Checking if open now...');
      final isOpenNow = _checkIsOpenNow(vendorsModel);
      if (isOpenNow) {
        print('Time to open! Auto-navigating to MainVendorPage');
        timer.cancel(); // หยุด timer
        if (mounted) {
          setState(() {}); // Rebuild UI → เข้า MainVendorPage
        }
      } else {
        print('Still closed. Next check in 30 sec.');
      }
    });
    print('Started auto-check timer (every 30 sec)');
  }

  // UI ปิด (ลบ _startCountdownTimer ออก เพื่อป้องกัน restart)
  Widget _buildClosedUI(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
    VendorModel vendorsModel,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: width * 0.25.w, color: color),
          SizedBox(height: 16),
          if (message == 'วันนี้ร้านปิด')
            ValueListenableBuilder<String>(
              valueListenable: _countdownNotifier,
              builder: (context, countdownText, child) {
                if (countdownText.isEmpty)
                  return const SizedBox.shrink(); // Fallback ถ้าไม่มี text
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StoreSettingsPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 74.w,
                      vertical: 20.h,
                    ),
                    backgroundColor: mainColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    countdownText,
                    style: styles(
                      fontSize: 14.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          if (message == 'ปิดชั่วคราว')
            Text(
              'กรุณารอการแจ้งเตือนจากผู้ดูแล',
              style: styles(fontSize: 14.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  void _startCountdownTimer(VendorModel vendorsModel) {
    _countdownTimer?.cancel();
    final nextOpenTime = _calculateNextOpenTime(vendorsModel);
    if (nextOpenTime == null) {
      _countdownNotifier.value = 'ไม่พบเวลาทำการ'; // ใช้ notifier
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final duration = nextOpenTime.difference(now);
      if (duration.isNegative) {
        print('Countdown reached zero – Auto-opening store');
        timer.cancel();
        _countdownNotifier.value = ''; // Clear text
        if (mounted) {
          setState(() {}); // Rebuild ครั้งเดียวเพื่อเข้า Main
        }
        return;
      }

      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      final text =
          '$hours:$minutes:$seconds'; // แก้: เพิ่ม leading zero ถ้าต้องการ (optional: '${hours.toString().padLeft(2,'0')}:${minutes.toString().padLeft(2,'0')}:${seconds.toString().padLeft(2,'0')}');
      _countdownNotifier.value = text; // ใช้ notifier – ไม่ setState
    });
    print('Started countdown timer (every 1 sec) to $nextOpenTime');
  }

  // ใหม่: Reset countdown notifier (สำหรับรีเฟรช)
  void _resetCountdown() {
    _countdownNotifier.value = '';
    _countdownTimer?.cancel();
  }

  // แก้: คำนวณเวลาถึงเปิดถัดไป (handle after close → next day, และ loop หาวันไม่ปิด)
  DateTime? _calculateNextOpenTime(VendorModel vendorsModel) {
    final now = DateTime.now();
    String currentDayKey = _getDayKey(now.weekday);
    int daysAhead = 0;

    while (daysAhead < 7) {
      // Loop สูงสุด 7 วัน ป้องกัน infinite
      final dayHours = vendorsModel.storeHours?[currentDayKey];
      if (dayHours != null &&
          dayHours['closed'] != true &&
          dayHours['open'] != null &&
          dayHours['close'] != null) {
        try {
          final openParts = (dayHours['open'] as String).split(':');
          final closeParts = (dayHours['close'] as String).split(':');
          final openHour = int.parse(openParts[0]);
          final openMinute = int.parse(openParts[1]);
          final closeHour = int.parse(closeParts[0]);
          final closeMinute = int.parse(closeParts[1]);

          final targetDay = now.add(Duration(days: daysAhead));
          final openTime = DateTime(
            targetDay.year,
            targetDay.month,
            targetDay.day,
            openHour,
            openMinute,
          );
          final closeTime = DateTime(
            targetDay.year,
            targetDay.month,
            targetDay.day,
            closeHour,
            closeMinute,
          );

          if (daysAhead == 0) {
            // วันนี้: ถ้าก่อน open → return open
            if (now.isBefore(openTime)) {
              return openTime;
            }
            // ถ้ากลางวัน (open < now < close) → ไม่ควรเกิดเพราะ !isOpenNow
            if (now.isAfter(openTime) && now.isBefore(closeTime)) {
              return null; // Error case
            }
            // หลัง close → ไปวันถัดไป
          } else {
            // วันถัดไป: return open time
            return openTime;
          }
        } catch (e) {
          print('Error parsing times for $currentDayKey: $e');
        }
      }
      // ถ้าวันนี้ปิดหรือ error → ขยับวันถัดไป
      daysAhead++;
      int nextWeekday = (now.weekday + daysAhead - 1) % 7 + 1; // Handle sunday
      currentDayKey = _getDayKey(nextWeekday);
    }
    print('No open day found in next 7 days');
    return null;
  }

  // _getDayKey (เดิมจากแก้ก่อนหน้า)
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
}
