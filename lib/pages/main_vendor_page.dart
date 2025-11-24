import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vendor_box/pages/general_upload.dart';
import 'package:vendor_box/pages/nav_pages/eanings_page.dart';
import 'package:vendor_box/pages/nav_pages/edit_page.dart';
import 'package:vendor_box/pages/nav_pages/logout.dart';
import 'package:vendor_box/pages/nav_pages/orders.dart';
import 'package:badges/badges.dart' as badges;
import 'package:vendor_box/pages/nav_pages/upload_page.dart';
import 'package:vendor_box/pages/nav_pages/store_settings_page.dart'; // ใหม่: Import StoreSettingsPage
import 'package:vendor_box/services/sevice.dart';

class MainVendorPage extends StatefulWidget {
  const MainVendorPage({super.key});

  @override
  State<MainVendorPage> createState() => _MainVendorPageState();
}

class _MainVendorPageState extends State<MainVendorPage> {
  final String vendorUid = auth.currentUser!.uid; // Cache uid
  late Stream<QuerySnapshot> _ordersStream;

  @override
  void initState() {
    super.initState();
    // ปรับ query: รองรับ 'status' = 'preparing' หรือ 'pending' (whereIn)
    // หรือใช้ 'accepted' = false ถ้า field ชื่อนั้น
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: vendorUid)
        .where('status', whereIn: ['preparing', 'pending']) // แก้: หลายค่า
        .snapshots();
  }

  int _pageIndex = 0;
  // อัปเดต: เพิ่ม StoreSettingsPage ใน list (index 4, ก่อน Logout)
  final List<Widget> _page = [
    const EarningPage(),
    const GeneralTab(),
    const EditPage(),
    const OrderPage(),
    const StoreSettingsPage(), // ใหม่
    const LogOutPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        // Debug print (ลบหลัง test)
        if (snapshot.hasData) {
          print(
            '=== DEBUG Orders Stream: ${snapshot.data!.docs.length} pending orders for uid $vendorUid ===',
          );
          if (snapshot.data!.docs.isNotEmpty) {
            print(
              'First order data: ${snapshot.data!.docs.first.data()}',
            ); // ดู field ใน doc
          }
        } else if (snapshot.hasError) {
          print('=== DEBUG Stream Error: ${snapshot.error} ===');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Material(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Material(
            child: Center(
              child: Text('Error loading orders: ${snapshot.error}'),
            ),
          );
        }

        return Scaffold(
          bottomNavigationBar: BottomNavigationBar(
            unselectedItemColor: Colors.grey,
            currentIndex: _pageIndex,
            selectedLabelStyle: GoogleFonts.righteous(fontSize: 16),
            onTap: (value) {
              setState(() {
                _pageIndex = value;
              });
            },
            selectedItemColor: mainColor,
            // อัปเดต: เพิ่ม item สำหรับ Settings (index 4)
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
                  showBadge: snapshot.data!.docs.isEmpty ? false : true,
                  badgeContent: Text(
                    snapshot.data!.docs.length.toString(),
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
                  _pageIndex == 4
                      ? IconlyBold.setting
                      : IconlyLight.setting, // ใหม่: Settings icon
                ),
                label: 'Settings',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  _pageIndex == 5 ? IconlyBold.logout : IconlyLight.logout,
                ),
                label: 'Sign Out',
              ),
            ],
          ),
          body: _page[_pageIndex],
        );
      },
    );
  }
}
