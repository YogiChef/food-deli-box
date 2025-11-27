// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/controllers/vendor_controller.dart';
import 'package:vendor_box/models/vendor_model.dart';
import 'package:vendor_box/pages/nav_pages/logout.dart';
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
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  // ใหม่: Mapping table short → full lowercase (สำหรับ save/load Firestore)
  final Map<String, String> _dayMap = {
    'mon': 'monday',
    'tue': 'tuesday',
    'wed': 'wednesday',
    'thu': 'thursday',
    'fri': 'friday',
    'sat': 'saturday',
    'sun': 'sunday',
  };
  String? _currentStatus;
  bool _isTemporarilyClosed =
      false; // เพิ่ม: สถานะปิดชั่วคราว (default false = เปิด)

  @override
  void dispose() {
    // ใหม่: Cancel async work ถ้ามี (e.g., Timer) – ปัจจุบันไม่มี แต่เพิ่มเพื่อ safe
    super.dispose();
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
    print(
      'StoreSettings: Current dayKey: $dayKey (weekday=${now.weekday})',
    ); // ใหม่: Debug
    final dayEntry = hours[dayKey];
    print('StoreSettings: Day entry: $dayEntry'); // ใหม่: Debug

    // เพิ่ม: เช็ค closed ต่อวันก่อน
    if (dayEntry?['closed'] == true) {
      if (mounted) {
        setState(() {
          _currentStatus = 'ปิดทั้งวัน';
        });
      }
      print('StoreSettings: Day closed=true'); // ใหม่: Debug
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
      print(
        'StoreSettings: Parsed times, status=$_currentStatus',
      ); // ใหม่: Debug
    } catch (e) {
      _currentStatus = 'Invalid Hours';
      print('Update status error: $e'); // เพิ่ม debug
    }
  }

  // แก้: Helper สำหรับ day key (แก้บั๊ก mapping เดียวกับ Landing)
  String _getDayKey(int weekday) {
    const days = [
      'monday', // index 0: weekday=1
      'tuesday', // 1: weekday=2
      'wednesday', // 2: weekday=3
      'thursday', // 3: weekday=4
      'friday', // 4: weekday=5
      'saturday', // 5: weekday=6
      'sunday', // 6: weekday=7
    ];
    return days[weekday -
        1]; // ตรง forward: Mon=1→0='monday', Thu=4→3='thursday', Sun=7→6='sunday'
  }

  // แก้: เพิ่ม param bool? isClosed สำหรับ handle toggle closed ต่อวัน
  void _onSaveTime(String day, String? open, String? close, bool? isClosed) {
    final shortLower = day.toLowerCase(); // e.g., 'Mon' → 'mon'
    final fullKey = _dayMap[shortLower] ?? shortLower; // Map to 'monday'
    print('Save: UI day=$day → short=$shortLower → fullKey=$fullKey'); // Debug
    final Map<String, dynamic> dayEntry =
        hours[fullKey] ??
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
        hours[fullKey] = dayEntry;
      });
      _updateCurrentStatus(); // เรียกที่นี่ OK เพราะไม่ใช่ใน build
    } else if (dayEntry['open'] == null &&
        dayEntry['close'] == null &&
        !dayEntry['closed']) {
      setState(() {
        hours.remove(fullKey);
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
            if (mounted) {
              // ใหม่: เช็ค mounted ก่อน showSnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('คำเตือน: เวลาปิดควรหลังเวลาเปิด'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          print('Validation error: $e');
        }
      }
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
      if (mounted) {
        // ใหม่: เช็ค mounted ก่อน showSnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกเวลาอย่างน้อยหนึ่งวัน')),
        );
      }
      return;
    }
    try {
      await _vendorController.saveTemporaryClose(_isTemporarilyClosed);
      await _vendorController.saveStoreHours(hours);

      // ใหม่: เช็ค isOpenNow หลังเซฟ (load ข้อมูลใหม่จาก Firestore)
      final uid = _auth.currentUser!.uid;
      final doc = await _firestore.collection('vendors').doc(uid).get();
      if (doc.exists) {
        final updatedModel = VendorModel.fromJson(
          doc.data() as Map<String, dynamic>,
        );
        final isOpenNow =
            !_isTemporarilyClosed &&
            _checkIsOpenNow(updatedModel); // ใช้ฟังก์ชันใหม่

        if (mounted) {
          // ใหม่: เช็ค mounted ก่อน showSnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'บันทึกสำเร็จ! สถานะ: ${isOpenNow ? 'เปิดแล้ว' : 'ปิด'}',
              ),
            ),
          );
        }

        // ใหม่: ถ้าเปิดได้ทันที → pop กลับ Landing (Stream จะเข้า Main อัตโนมัติ)
        if (isOpenNow && mounted) {
          // ใหม่: เช็ค mounted ก่อน pop
          print('Saved and open now – Auto-activating by popping to Landing');
          Navigator.of(
            context,
          ).pop(); // กลับ Landing → Timer และ Stream จะ handle
        }
      }
    } catch (e) {
      print('Save error: $e');
      if (mounted) {
        // ใหม่: เช็ค mounted ก่อน showSnackBar ใน catch
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
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
            print('Error parsing store hours: $e');
          }
        }
      }
    }
    return isOpenNow;
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
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: IconButton(
                  icon: Icon(IconlyLight.logout),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const LogOutPage(), // Replace Placeholder with your target page widget
                      ),
                    );
                  },
                ),
              ),
            ],
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
            // แก้: Load hours – map full keys → hours[fullKey] สำหรับ internal (UI ใช้ short labels)
            final Map<String, Map<String, dynamic>> loadedHours = {};
            final rawHours =
                vendorData['storeHours'] as Map<String, dynamic>? ?? {};
            rawHours.forEach((fullKey, value) {
              loadedHours[fullKey] = Map<String, dynamic>.from(
                value as Map<String, dynamic>,
              )..putIfAbsent('closed', () => false);
              print('Loaded: fullKey=$fullKey, value=$value'); // Debug
            });
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
                ..._days.asMap().entries.map((entry) {
                  final index = entry.key;
                  final shortDay = entry.value; // 'Mon'
                  final fullKey = _getDayKey(
                    index + 1,
                  ); // Map index → full 'monday' (weekday=1 for Mon)
                  final dayEntry =
                      hours[fullKey] ??
                      {
                        'open': null,
                        'close': null,
                        'closed': false,
                      }; // Default ครบ
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: TimeSelectorWidget(
                      key: ValueKey(
                        '$shortDay-${dayEntry['closed']}-${dayEntry['open'] ?? ''}-${dayEntry['close'] ?? ''}', // Safe key (null to empty string)
                      ),
                      dayLabel: shortDay, // แสดง short 'Mon'
                      onSave: (d, o, c) =>
                          _onSaveTime(d, o, c, null), // สำหรับ time change
                      onClosed: (isClosed) => _onSaveTime(
                        shortDay,
                        null,
                        null,
                        isClosed,
                      ), // สำหรับ toggle closed (ส่ง shortDay เพื่อ map ใน _onSaveTime)
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
                }),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsetsGeometry.only(
          left: 20.w,
          right: 20.w,
          top: 12.h,
          bottom: 6,
        ),
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
    );
  }
}
