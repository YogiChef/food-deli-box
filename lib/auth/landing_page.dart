import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/models/vendor_model.dart';
import 'package:vendor_box/pages/main_vendor_page.dart';
import 'package:vendor_box/auth/vendor_auth.dart'; // นำเข้า VendorAuthPage
import 'package:vendor_box/services/sevice.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key}); // เพิ่ม const constructor

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final FirebaseAuth auth =
      FirebaseAuth.instance; // แก้: เพิ่ม declaration สำหรับ signOut

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        print(
          'Auth snapshot: hasData = ${authSnapshot.hasData}, uid = ${authSnapshot.data?.uid}',
        ); // Debug
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          print('Waiting for auth...');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          print('No user – Going to VendorAuthPage (Login)'); // Debug
          return const VendorAuthPage(); // ไป login ถ้า no user
        }

        final CollectionReference _vendorsStream = firestore.collection(
          'vendors',
        );
        return Scaffold(
          body: StreamBuilder<DocumentSnapshot>(
            stream: _vendorsStream.doc(authSnapshot.data!.uid).snapshots(),
            builder: (context, vendorSnapshot) {
              print(
                'Vendor snapshot: hasData = ${vendorSnapshot.hasData}, exists = ${vendorSnapshot.data?.exists}',
              ); // Debug
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
                print(
                  'No vendor doc – Going to VendorAuthPage (Login/Setup)',
                ); // Debug – ไป login แทน register
                return const VendorAuthPage(); // ไป login/setup ถ้า doc ไม่มี (ไม่ไป register)
              }

              final VendorModel vendorsModel = VendorModel.fromJson(
                vendorSnapshot.data!.data() as Map<String, dynamic>,
              );

              // ใหม่: เช็ค store hours
              bool isOpenNow = true; // Default
              if (vendorsModel.storeHours != null &&
                  vendorsModel.storeHours!.isNotEmpty) {
                final now = DateTime.now();
                final dayKey = _getDayKey(now.weekday);
                print(
                  'Debug: Current dayKey = $dayKey',
                ); // เพิ่ม debug เพื่อเช็ควัน
                final dayHours = vendorsModel.storeHours![dayKey];
                print('Debug: dayHours = $dayHours'); // Debug ข้อมูลวันนั้น
                if (dayHours != null) {
                  final closed =
                      dayHours['closed'] as bool? ??
                      false; // ใหม่: เช็ค closed flag
                  if (closed == true) {
                    isOpenNow = false; // ปิดวันนี้ทันที
                    print('Debug: Closed flag = true, isOpenNow = false');
                    // Skip เช็คเวลา
                  }
                  final openStr = dayHours['open'] as String?;
                  final closeStr = dayHours['close'] as String?;
                  // แก้: Handle null ก่อน cast เพื่อไม่ throw error
                  if (openStr != null && closeStr != null) {
                    try {
                      final openParts = openStr.split(':');
                      final closeParts = closeStr.split(':');
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
                      isOpenNow =
                          now.isAfter(openTime) && now.isBefore(closeTime);
                      print(
                        'Debug: isOpenNow = $isOpenNow, now=$now, open=$openTime, close=$closeTime',
                      ); // Debug สถานะ
                    } catch (e) {
                      print('Error parsing store hours: $e');
                      isOpenNow = true; // Fallback ชัดเจน
                    }
                  } else {
                    print(
                      'Debug: Partial hours – open=$openStr, close=$closeStr',
                    ); // Debug partial
                    // ถ้า partial: assume open ถ้า open null หรือ close null
                    if (openStr == null)
                      isOpenNow = true; // เปิดทั้งวัน
                    else if (closeStr == null) {
                      // เปิดหลัง openTime ถึงสิ้นวัน
                      try {
                        final openParts = openStr.split(':');
                        final openHour = int.parse(openParts[0]);
                        final openMinute = int.parse(openParts[1]);
                        final openTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          openHour,
                          openMinute,
                        );
                        isOpenNow = now.isAfter(openTime);
                      } catch (e) {
                        print('Error parsing open: $e');
                        isOpenNow = true;
                      }
                    }
                  }
                }
              }

              if (vendorsModel.approved == true) {
                print('Approved – Going to MainVendorPage (Home)'); // Debug
                if (!isOpenNow) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storage_outlined,
                          size: 64,
                          color: Colors.orange,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'ร้านปิดวันนี้ – ตรวจสอบ orders ในเวลาทำการ',
                          style: styles(fontSize: 16.sp),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: Text('รีเฟรช'),
                        ),
                      ],
                    ),
                  );
                }
                return const MainVendorPage(); // ไป home ถ้า approved และเปิด
              } else {
                print('Not approved – Showing pending UI'); // Debug
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
                          // Stream จะ handle navigate ไป auth page
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

  // แก้: Helper สำหรับ day key ให้ถูกต้อง (เหมือนใน DeliService)
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
    final int index = (weekday == 7) ? 0 : weekday;
    return days[index];
  }
}
