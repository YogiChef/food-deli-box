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
          if (snapshot.data!.docs.isEmpty) {
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

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: ((context, index) {
              final venderProductData = snapshot.data!.docs[index];
              return Slidable(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VendorProductDetail(productData: venderProductData),
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
                        venderProductData['pqty'] <= 0
                            ? Stack(
                                children: [
                                  SizedBox(
                                    height: 60.w,
                                    width: 80.w,
                                    child: Image(
                                      image: NetworkImage(
                                        venderProductData['imageUrl'][0],
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black87.withOpacity(0.6),
                                      child: Center(
                                        child: Text(
                                          'Out of Stock',
                                          style: styles(
                                            color: Colors.white,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : SizedBox(
                                height: 60.w,
                                width: 80.w,
                                child: Image.network(
                                  venderProductData['imageUrl'][0],
                                  fit: BoxFit.cover,
                                ),
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
                                venderProductData['proName'],
                                style: styles(fontSize: 13.sp),
                              ),
                              Text(
                                '฿${venderProductData['price'].toString()}',
                                style: styles(fontSize: 12.sp),
                              ),
                              Text(
                                '${venderProductData['pqty'].toString()} pcs.',
                                style: styles(
                                  fontSize: 12.sp,
                                  color: venderProductData['pqty'] <= 10
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
                key: const ValueKey(0),
                startActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  // dismissible: DismissiblePane(onDismissed: () {}),
                  children: [
                    SlidableAction(
                      flex: 2,
                      onPressed: (context) async {
                        await firestore
                            .collection('products')
                            .doc(venderProductData['proId'])
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
                            .doc(venderProductData['proId'])
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
            }),
          );
        },
      ),
    );
  }
}
