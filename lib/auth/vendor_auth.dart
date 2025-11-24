import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/auth/vendor_registor_page.dart';
import 'package:vendor_box/models/vendor_model.dart';
import 'package:vendor_box/pages/main_vendor_page.dart';
import 'package:vendor_box/services/sevice.dart';

class VendorAuthPage extends StatefulWidget {
  const VendorAuthPage({super.key});

  @override
  State<VendorAuthPage> createState() => _VendorAuthPageState();
}

class _VendorAuthPageState extends State<VendorAuthPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        print(
          'Auth Snapshot: hasData=${authSnapshot.hasData}, user=${authSnapshot.data?.uid}',
        );

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: Text('กำลังโหลด...')));
        }

        if (authSnapshot.hasError) {
          print('Auth Error: ${authSnapshot.error}');
          return Scaffold(
            body: Center(child: Text('เกิดข้อผิดพลาด: ${authSnapshot.error}')),
          );
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return SignInScreen(
            providers: [EmailAuthProvider()],
            actions: [
              AuthStateChangeAction<SignedIn>((context, _) {
                print('User signed in: \${_users?.uid}');
              }),
            ],
          );
        }

        final CollectionReference _vendorsStream = firestore.collection(
          'vendors',
        );
        return Scaffold(
          body: StreamBuilder<DocumentSnapshot>(
            stream: _vendorsStream.doc(authSnapshot.data!.uid).snapshots(),
            builder: (context, vendorSnapshot) {
              if (vendorSnapshot.hasError) {
                print('Vendor error: ${vendorSnapshot.error}');
                return Center(
                  child: Text('เกิดข้อผิดพลาด: ${vendorSnapshot.error}'),
                );
              }

              if (vendorSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!vendorSnapshot.hasData || !vendorSnapshot.data!.exists) {
                print('No vendor doc – Going to VendorRegistorPage');
                return const VendorRegistorPage();
              }

              final VendorModel vendorModel = VendorModel.fromJson(
                vendorSnapshot.data!.data() as Map<String, dynamic>,
              );

              // ใหม่: เช็ค store hours (คล้าย landing_page)
              bool isOpenNow = true;
              if (vendorModel.storeHours != null &&
                  vendorModel.storeHours!.isNotEmpty) {
                final now = DateTime.now();
                final dayKey = _getDayKey(now.weekday);
                final dayHours = vendorModel.storeHours![dayKey];
                if (dayHours != null) {
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
                    isOpenNow =
                        now.isAfter(openTime) && now.isBefore(closeTime);
                  } catch (e) {
                    print('Error parsing store hours: $e');
                  }
                }
              }

              if (vendorModel.approved == true) {
                if (!isOpenNow) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store_mall_directory_outlined,
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
                return const MainVendorPage();
              }

              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.network(
                          vendorModel.image.isNotEmpty
                              ? vendorModel.image
                              : 'https://via.placeholder.com/90',
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Image Load Error: $error');
                            return const Icon(Icons.error, size: 90);
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        vendorModel.bussinessName.isNotEmpty
                            ? vendorModel.bussinessName
                            : 'ไม่ทราบชื่อธุรกิจ',
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
                          print('Signing Out: UID=${authSnapshot.data!.uid}');
                          await FirebaseAuth.instance.signOut();
                          setState(() {});
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ใหม่: Helper สำหรับ day key (copy จาก landing_page)
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
}
