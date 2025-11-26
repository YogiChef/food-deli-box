// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // เพิ่ม: สำหรับ addPostFrameCallback
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

  // แก้: Type Map<String, Map<String, dynamic>> เพื่อรองรับ 'closed': bool
  Map<String, Map<String, dynamic>> hours = {};
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
  bool _isTemporarilyClosed =
      false; // เพิ่ม: สถานะปิดชั่วคราว (default false = เปิด)

  @override
  void initState() {
    super.initState();
  }

  void _updateCurrentStatus() {
    // เพิ่ม: เช็ค temporary ก่อน (override ทุกอย่าง)
    if (_isTemporarilyClosed) {
      if (mounted) {
        // เพิ่ม: เช็ค mounted เพื่อ avoid setState after dispose
        setState(() {
          _currentStatus = 'ปิดชั่วคราว';
        });
      }
      return;
    }

    final now = DateTime.now();
    final dayKey = _getDayKey(now.weekday);
    final dayEntry = hours[dayKey];

    // เพิ่ม: เช็ค closed ต่อวันก่อน
    if (dayEntry?['closed'] == true) {
      if (mounted) {
        setState(() {
          _currentStatus = 'ปิดทั้งวัน';
        });
      }
      return;
    }

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
      if (mounted) {
        setState(() {
          _currentStatus = now.isAfter(openTime) && now.isBefore(closeTime)
              ? 'Open Now'
              : 'Closed';
        });
      }
    } catch (e) {
      _currentStatus = 'Invalid Hours';
      print('Update status error: $e'); // เพิ่ม debug
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

  // แก้: เพิ่ม param bool? isClosed สำหรับ handle toggle closed ต่อวัน
  void _onSaveTime(String day, String? open, String? close, bool? isClosed) {
    final lowerDay = day.toLowerCase();
    final Map<String, dynamic> dayEntry =
        hours[lowerDay] ??
        <String, dynamic>{'open': null, 'close': null, 'closed': false};

    bool hasChange = false;

    // เพิ่ม: Handle closed
    if (isClosed != null) {
      dayEntry['closed'] = isClosed;
      hasChange = true;
      if (isClosed) {
        dayEntry['open'] = null; // Clear times ถ้าปิด
        dayEntry['close'] = null;
        print('Set $day to closed');
      } else {
        print('Set $day to open');
      }
    }

    // Handle open/close times (skip ถ้า closed)
    if (!dayEntry['closed'] && open != null) {
      dayEntry['open'] = open;
      hasChange = true;
      print('Updated open for $day: $open');
    }
    if (!dayEntry['closed'] && close != null) {
      dayEntry['close'] = close;
      hasChange = true;
      print('Updated close for $day: $close');
    }

    if (hasChange) {
      setState(() {
        hours[lowerDay] = dayEntry;
      });
      _updateCurrentStatus(); // เรียกที่นี่ OK เพราะไม่ใช่ใน build
    } else if (dayEntry['open'] == null &&
        dayEntry['close'] == null &&
        !dayEntry['closed']) {
      setState(() {
        hours.remove(lowerDay);
      });
    }

    // Validation (skip ถ้า closed หรือ null)
    if (!dayEntry['closed'] &&
        dayEntry['open'] != null &&
        dayEntry['close'] != null) {
      final openStr = dayEntry['open'] as String;
      final closeStr = dayEntry['close'] as String;
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

  // เพิ่ม: Method สำหรับ toggle temporary close
  Future<void> _toggleTemporaryClose(bool isClosed) async {
    setState(() {
      _isTemporarilyClosed = isClosed;
    });

    try {
      // สมมติ VendorController มี method นี้; ถ้าไม่มี ให้เซฟตรง: _firestore.collection('vendors').doc(_auth.currentUser!.uid).update({'temporarilyClosed': isClosed});
      await _vendorController.saveTemporaryClose(isClosed);
      await _firestore.collection('vendors').doc(_auth.currentUser!.uid).update(
        {
          'temporarilyClosed': isClosed, // true = ปิด
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      _updateCurrentStatus(); // เรียกที่นี่ OK

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isClosed ? 'ปิดร้านชั่วคราวแล้ว' : 'เปิดร้านแล้ว'),
          backgroundColor: isClosed ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Toggle error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      // Rollback state ถ้า error
      setState(() {
        _isTemporarilyClosed = !isClosed;
      });
    }
  }

  Future<void> _saveHours() async {
    if (hours.values
        .where(
          (entry) =>
              entry['open'] != null ||
              entry['close'] != null ||
              entry['closed'] == true,
        )
        .isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกเวลาอย่างน้อยหนึ่งวัน')),
      );
      return;
    }
    try {
      // เพิ่ม: เซฟ temporary close ร่วม (ถ้า Controller รองรับ)
      await _vendorController.saveTemporaryClose(_isTemporarilyClosed);

      await _vendorController.saveStoreHours(hours); // Save รวม closed field
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56.0), // สูงปกติ
        child: ClipRRect(
          // Clip เฉพาะด้านล่าง
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(12.0),
            bottomRight: Radius.circular(12.0),
          ),
          child: AppBar(
            title: Text(
              'ตั้งค่าเวลาร้านค้า',
              style: styles(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            backgroundColor: mainColor,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
          ),
        ),
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
          // แก้: โหลดข้อมูลเฉพาะตอนแรก (hours.isEmpty) เพื่อไม่ให้ overwrite การเปลี่ยนแปลง local
          if (hours.isEmpty) {
            final Map<String, Map<String, dynamic>> loadedHours =
                Map<String, Map<String, dynamic>>.from(
                  (vendorData['storeHours'] as Map<String, dynamic>?)?.map(
                        (k, v) => MapEntry(
                          k,
                          Map<String, dynamic>.from(v as Map<String, dynamic>)
                            ..putIfAbsent(
                              'closed',
                              () => false,
                            ), // เพิ่ม default closed: false
                        ),
                      ) ??
                      {},
                );
            hours = loadedHours;

            // เพิ่ม: โหลด temporary close (ใช้ temporarilyClosed เป็นหลัก, ignore isTemporarilyOpen ถ้าซ้ำ)
            _isTemporarilyClosed = vendorData['temporarilyClosed'] ?? false;
            print('Loaded temporary closed: $_isTemporarilyClosed'); // Debug

            // แก้หลัก: ใช้ addPostFrameCallback เพื่อ delay _updateCurrentStatus หลัง build เสร็จ
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateCurrentStatus();
              }
            });
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current status card (สมมติมี code เดิม; ถ้าไม่มีให้เพิ่ม Card แสดง _currentStatus)
                Text(
                  'เลือกเวลาทำการรายวัน',
                  style: styles(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12.h),

                // แก้: ส่ง props สำหรับ closed และ callback ใหม่ (fix null safety)
                ..._days.map((day) {
                  final lowerDay = day.toLowerCase();
                  final dayEntry =
                      hours[lowerDay] ??
                      {
                        'open': null,
                        'close': null,
                        'closed': false,
                      }; // Default ครบ
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: TimeSelectorWidget(
                      key: ValueKey(
                        '${day}-${dayEntry['closed']}-${dayEntry['open'] ?? ''}-${dayEntry['close'] ?? ''}', // Safe key (null to empty string)
                      ),
                      dayLabel: day,
                      onSave: (d, o, c) =>
                          _onSaveTime(d, o, c, null), // สำหรับ time change
                      onClosed: (isClosed) => _onSaveTime(
                        day,
                        null,
                        null,
                        isClosed,
                      ), // สำหรับ toggle closed
                      // แก้: ใช้ dayEntry โดยตรง – no null error
                      currentOpen: !(dayEntry['closed'] as bool)
                          ? (dayEntry['open'] as String?)
                          : null,
                      currentClose: !(dayEntry['closed'] as bool)
                          ? (dayEntry['close'] as String?)
                          : null,
                      currentClosed: dayEntry['closed'] as bool,
                    ),
                  );
                }).toList(),

                SizedBox(height: 12.h),
                Center(
                  child: SizedBox(
                    width: width * 0.9.w,
                    child: BottonWidget(
                      label: 'บันทึก',
                      style: styles(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      icon: Icons.save,
                      press: _saveHours,
                      color: mainColor,
                      height: 50.h,
                    ),
                  ),
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
