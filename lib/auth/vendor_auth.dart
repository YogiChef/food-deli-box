// import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
// import 'package:firebase_ui_auth/firebase_ui_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:vendor_box/auth/vendor_registor_page.dart';

// class VendorAuthPage extends StatefulWidget {
//   const VendorAuthPage({super.key});

//   @override
//   State<VendorAuthPage> createState() => _VendorAuthPageState();
// }

// ignore_for_file: avoid_print, unnecessary_null_comparison

// class _VendorAuthPageState extends State<VendorAuthPage> {
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       initialData: FirebaseAuth.instance.currentUser,
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return SignInScreen(providers: [EmailAuthProvider()]);
//         } else {
//           return const VendorRegistorPage();
//         }
//       },
//     );
//   }
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
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
              AuthStateChangeAction<SignedIn>((context, state) {
                print('Signed In: UID=${state.user?.uid}');
                setState(() {});
              }),
              AuthStateChangeAction<AuthFailed>((context, state) {
                print(
                  'Auth Failed: exception=${state.exception}, message=${state.exception.toString()}',
                );
                // จัดการข้อผิดพลาดอย่างปลอดภัย
                String errorMessage = 'ลงชื่อเข้าใช้ล้มเหลือ: ไม่ทราบสาเหตุ';
                if (state.exception != null) {
                  errorMessage =
                      'ลงชื่อเข้าใช้ล้มเหลือ: ${state.exception.toString()}';
                  // ถ้าเป็น FirebaseAuthException
                  if (state.exception is FirebaseAuthException) {
                    final firebaseException =
                        state.exception as FirebaseAuthException;
                    errorMessage =
                        'ลงชื่อเข้าใช้ล้มเหลือ: ${firebaseException.message ?? firebaseException.code}';
                  }
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(errorMessage)));
                });
              }),
            ],
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: firestore
              .collection('vendors')
              .doc(authSnapshot.data!.uid)
              .snapshots(),
          builder: (context, vendorSnapshot) {
            print(
              'Vendor Snapshot: exists=${vendorSnapshot.data?.exists}, data=${vendorSnapshot.data?.data()}',
            );

            if (vendorSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: Text('กำลังโหลดข้อมูลผู้ใช้...')),
              );
            }

            if (vendorSnapshot.hasError) {
              print('Firestore Error: ${vendorSnapshot.error}');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'เกิดข้อผิดพลาดในการดึงข้อมูล: ${vendorSnapshot.error}',
                    ),
                  ),
                );
              });
              return const Scaffold(
                body: Center(child: Text('เกิดข้อผิดพลาดในการดึงข้อมูล')),
              );
            }

            if (!vendorSnapshot.data!.exists) {
              print('No Vendor Document for UID: ${authSnapshot.data!.uid}');
              return const VendorRegistorPage();
            }

            final data = vendorSnapshot.data!.data() as Map<String, dynamic>?;
            print('Firestore Data: $data');

            VendorModel vendorModel;
            try {
              vendorModel = VendorModel.fromJson(
                data ??
                    {
                      'approved': false,
                      'vendorId': '',
                      'bussinessName': 'Unknown',
                      'city': '',
                      'country': '',
                      'address': '',
                      'vzipcode': '',
                      'email': '',
                      'image': '',
                      'phone': '',
                      'state': '',
                      'category': '',
                      'taxStatus': '',
                      'taxNo': '',
                    },
              );
            } catch (e) {
              print('Error parsing VendorModel: $e');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เกิดข้อผิดพลาดในการแปลงข้อมูลผู้ใช้: $e'),
                  ),
                );
              });
              return const Scaffold(
                body: Center(
                  child: Text('เกิดข้อผิดพลาดในการแปลงข้อมูลผู้ใช้'),
                ),
              );
            }

            print(
              'Vendor Model: approved=${vendorModel.approved}, bussinessName=${vendorModel.bussinessName}',
            );

            if (vendorModel.approved == true) {
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
                      style: styles(fontSize: 20, fontWeight: FontWeight.w500),
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
        );
      },
    );
  }
}
