import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

              VendorModel vendorsModel = VendorModel.fromJson(
                vendorSnapshot.data!.data() as Map<String, dynamic>? ?? {},
              );
              if (vendorsModel.approved == true) {
                print('Approved – Going to MainVendorPage (Home)'); // Debug
                return const MainVendorPage(); // ไป home ถ้า approved
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
}
