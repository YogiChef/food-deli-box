// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/pages/vendor_chat_page.dart';
import 'package:vendor_box/services/sevice.dart';

class EarningPage extends StatefulWidget {
  const EarningPage({super.key});

  @override
  State<EarningPage> createState() => _EarningPageState();
}

class _EarningPageState extends State<EarningPage> {
  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int hour = now.hour;

    CollectionReference users = FirebaseFirestore.instance.collection(
      'vendors',
    );
    // FIXED: Filter for completed orders (adjust statuses as needed, e.g., 'completed', 'delivered')
    final Stream<QuerySnapshot> _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: auth.currentUser!.uid)
        .where(
          'status',
          whereIn: ['completed', 'delivered'],
        ) // FIXED: Only sum earnings from completed orders
        .snapshots();

    return FutureBuilder<DocumentSnapshot>(
      future: users.doc(auth.currentUser!.uid).get(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Text("Something went wrong");
        }

        if (snapshot.hasData && !snapshot.data!.exists) {
          return const Text("Document does not exist");
        }

        if (snapshot.connectionState == ConnectionState.done) {
          // FIXED: Null-safe access to vendor data
          final Map<String, dynamic>? data =
              snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text("No vendor data available"));
          }

          final double screenWidth = MediaQuery.of(
            context,
          ).size.width; // FIXED: Define width

          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: false,
              elevation: 0,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 20.h, right: 12.w),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22.r,
                          backgroundImage: data['image'] != null
                              ? NetworkImage(data['image'])
                              : null, // FIXED: Null-safe image
                          child: data['image'] == null
                              ? Icon(
                                  Icons.store,
                                  size: 22.r,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 12.w),
                          child: Text(
                            'Hi ${data['bussinessName'] ?? 'Vendor'}', // FIXED: Fallback for bussinessName
                            overflow: TextOverflow.ellipsis,
                            style: styles(
                              fontSize: 14.sp,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  hour >= 12 && hour < 18
                      ? Image.asset(
                          'images/cloud.png',
                          width: 40.w,
                          height: 40.h,
                        )
                      : Image.asset(
                          hour >= 6 && hour < 12
                              ? 'images/sun.png'
                              : 'images/moon.png',
                          height: 40.h,
                          width: 40.w,
                        ),
                ],
              ),
            ),
            body: StreamBuilder<QuerySnapshot>(
              stream: _ordersStream,
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SizedBox(
                      width: screenWidth * 0.5,
                      child: const LinearProgressIndicator(color: Colors.green),
                    ),
                  );
                }

                // FIXED: Safe calculation of total earnings
                double totalEarnings = 0.0;
                int totalOrders = snapshot.data!.docs.length;

                for (var orderDoc in snapshot.data!.docs) {
                  final orderData =
                      orderDoc.data() as Map<String, dynamic>? ?? {};
                  final List<dynamic>? itemsRaw =
                      orderData['items']; // FIXED: Access 'items' array directly
                  final List<Map<String, dynamic>> items = (itemsRaw ?? [])
                      .where(
                        (item) => item != null && item is Map<dynamic, dynamic>,
                      ) // FIXED: Filter null + specify dynamic Map type
                      .map((item) {
                        try {
                          // FIXED: Convert to typed Map (handle Firestore's Map<dynamic, dynamic>)
                          final convertedItem = Map<String, dynamic>.from(
                            item as Map<dynamic, dynamic>,
                          );
                          print(
                            '=== DEBUG SAFE MAP === Keys: ${convertedItem.keys.toList()}',
                          ); // Optional debug
                          return convertedItem;
                        } catch (e) {
                          print(
                            '=== DEBUG MAP CAST ERROR === Item type: ${item.runtimeType}, Error: $e',
                          ); // Log for debug
                          return <String, dynamic>{}; // Fallback empty Map
                        }
                      })
                      .where((item) => item.isNotEmpty) // Filter non-empty Maps
                      .toList();

                  print(
                    '=== DEBUG FINAL ITEMS === Length: ${items.length}',
                  ); // Optional: Check total

                  for (var item in items) {
                    final int qty =
                        (item['quantity'] as num?)?.toInt() ??
                        0; // FIXED: Use 'quantity' from item
                    final double price =
                        (item['price'] as num?)?.toDouble() ?? 0.0;
                    totalEarnings +=
                        qty *
                        price; // FIXED: Sum from items (no direct 'qty' in order)
                  }
                }

                print(
                  '=== DEBUG EARNINGS === Total Earnings: $totalEarnings, Orders: $totalOrders',
                ); // FIXED: Add debug log

                return SingleChildScrollView(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 70.h,
                        horizontal: 20.w,
                      ), // FIXED: Use .h/.w consistently
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Material(
                            borderRadius: BorderRadius.circular(15),
                            elevation: 10,
                            shadowColor: Colors.pink,
                            child: Container(
                              height: 150.h, // FIXED: Use .h
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              width: screenWidth * 0.8,
                              decoration: BoxDecoration(
                                color: Colors.pink.shade800,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      'Total Earnings',
                                      style: styles(
                                        fontSize: 16.sp,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      '฿${totalEarnings.toStringAsFixed(2)}', // FIXED: Use calculated totalEarnings
                                      style: styles(
                                        fontSize: 16.sp,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 70.h),
                          Material(
                            elevation: 15,
                            shadowColor: Colors.blueGrey,
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              height: 150.h,
                              padding: EdgeInsets.symmetric(vertical: 15.h),
                              width: screenWidth * 0.8,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade800,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(12.w),
                                    child: Text(
                                      'Total Orders',
                                      style: styles(
                                        fontSize: 16.sp,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(12.w),
                                    child: Text(
                                      totalOrders
                                          .toString(), // FIXED: Use calculated totalOrders
                                      style: styles(
                                        fontSize: 16.sp,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: Colors.green,
              child: const Icon(
                IconlyLight.chat,
                color: Colors.white,
                size: 35,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VendorChatPage(),
                  ),
                );
              },
            ),
          );
        }

        return Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.5,
            child: const LinearProgressIndicator(color: Colors.green),
          ),
        );
      },
    );
  }
}
