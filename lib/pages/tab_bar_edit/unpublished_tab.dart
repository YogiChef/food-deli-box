// ignore_for_file: sort_child_properties_last, no_leading_underscores_for_local_identifiers

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vendor_box/services/sevice.dart';

class UnpublishedTab extends StatelessWidget {
  const UnpublishedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> _productStream = FirebaseFirestore.instance
        .collection('products')
        .where('vendorId', isEqualTo: auth.currentUser!.uid)
        .where('approved', isEqualTo: false)
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
                child: CircularProgressIndicator(
              color: Colors.yellow.shade900,
            ));
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text(
              'This Unpublished \n\n has no items yet !',
              textAlign: TextAlign.center,
              style: styles(
                  fontSize: 20.sp,
                  color: Colors.yellow.shade900,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5),
            ));
          }

          return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: ((context, index) {
                final venderProductData = snapshot.data!.docs[index];
                return Slidable(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 60.w,
                            width: 80.w,
                            child: Image.network(
                              venderProductData['imageUrl'][0],
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Column(
                              children: [
                                Text(
                                  venderProductData['proName'],
                                  style: styles(fontSize: 12.sp),
                                ),
                                Text(
                                  '฿${venderProductData['price'].toStringAsFixed(2)}',
                                  style: styles(fontSize: 12.sp),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    key: const ValueKey(0),
                    startActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      dismissible: DismissiblePane(onDismissed: () {}),
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
                                .doc(
                                  venderProductData['proId'],
                                )
                                .update({'approved': true});
                          },
                          backgroundColor: const Color(0xFF21B7CA),
                          foregroundColor: Colors.white,
                          icon: Icons.approval_outlined,
                          label: 'Publish',
                        ),
                      ],
                    ));
              }));
        },
      ),
    );
  }
}
