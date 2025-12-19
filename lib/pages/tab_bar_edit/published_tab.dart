// ignore_for_file: sort_child_properties_last

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vendor_box/pages/tab_bar_edit/product_detail.dart';
import 'package:vendor_box/services/sevice.dart';

class PublishedTab extends StatelessWidget {
  const PublishedTab({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: no_leading_underscores_for_local_identifiers
    final Stream<QuerySnapshot> _productStream = FirebaseFirestore.instance
        .collection('products')
        .where('vendorId', isEqualTo: auth.currentUser!.uid)
        .where('approved', isEqualTo: true)
        .snapshots();
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _productStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return const Text('Something went wrong');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.yellow.shade900),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // FIXED: Guard !hasData
            return Center(
              child: Text(
                'This Published \n\n has no items yet !',
                textAlign: TextAlign.center,
                style: styles(
                  fontSize: 20.sp,
                  color: Colors.yellow.shade900,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs; // FIXED: Cache docs เพื่อ reuse
          return ListView.builder(
            physics:
                const ClampingScrollPhysics(), // FIXED: Prevent over-scroll/infinite
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final venderProductData =
                  docs[index].data()
                      as Map<
                        String,
                        dynamic
                      >; // FIXED: Cast to Map + safe access
              try {
                // FIXED: Guard imageUrl access - เช็ค null/empty ก่อน [0]
                final List<dynamic>? imageUrls = venderProductData['imageUrl'];
                final String imageUrl =
                    (imageUrls != null && imageUrls.isNotEmpty)
                    ? imageUrls[0]
                          .toString() // Safe [0]
                    : ''; // Fallback empty
                final bool hasImage = imageUrl.isNotEmpty;
                final int pqty =
                    (venderProductData['pqty'] as num?)?.toInt() ??
                    0; // FIXED: Safe cast num to int

                return Slidable(
                  key: ValueKey(
                    docs[index].id,
                  ), // FIXED: Unique key ด้วย doc.id (ไม่ใช่ const 0)
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VendorProductDetail(
                            productData: docs[index],
                          ), // Pass full doc
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          // FIXED: Guard out-of-stock overlay + fallback image
                          Stack(
                            children: [
                              SizedBox(
                                height: 60.w,
                                width: 80.w,
                                child: hasImage
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (
                                              context,
                                              error,
                                              stackTrace,
                                            ) => // FIXED: Error builder
                                            Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey,
                                              ),
                                            ),
                                      )
                                    : Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                        ),
                                      ), // Fallback placeholder
                              ),
                              if (pqty <= 0) // FIXED: Use safe pqty
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black87.withAlpha(60),
                                    child: const Center(
                                      child: Text(
                                        'Out of Stock',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  venderProductData['proName']?.toString() ??
                                      'Unnamed Product', // FIXED: Null-safe
                                  style: styles(fontSize: 13.sp),
                                ),
                                Text(
                                  '฿${(venderProductData['price'] as num?)?.toString() ?? '0'}', // FIXED: Safe price
                                  style: styles(fontSize: 12.sp),
                                ),
                                Text(
                                  '${pqty.toString()} pcs.',
                                  style: styles(
                                    fontSize: 12.sp,
                                    color: pqty <= 10
                                        ? Colors.red
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  startActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        flex: 2,
                        onPressed: (context) async {
                          await firestore
                              .collection('products')
                              .doc(
                                docs[index].id,
                              ) // FIXED: Use doc.id แทน proId (safe ถ้า proId != doc.id)
                              .delete();
                        },
                        backgroundColor: const Color(0xFFFE4A49),
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Delete',
                      ),
                      SlidableAction(
                        flex: 2,
                        onPressed: (context) async {
                          await firestore
                              .collection('products')
                              .doc(docs[index].id)
                              .update({'approved': false});
                        },
                        backgroundColor: const Color(0xFF21B7CA),
                        foregroundColor: Colors.white,
                        icon: Icons.approval_outlined,
                        label: 'Unpublish',
                      ),
                    ],
                  ),
                );
              } catch (e) {
                // FIXED: Try-catch per item เพื่อไม่ crash whole list
                print('Error rendering product at index $index: $e'); // Debug
                return ListTile(
                  // Fallback tile
                  title: const Text('Error loading product'),
                  subtitle: Text('Index: $index - $e'),
                  leading: const Icon(Icons.error, color: Colors.red),
                );
              }
            },
          );
        },
      ),
    );
  }
}
