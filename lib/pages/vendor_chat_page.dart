// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:vendor_box/pages/chat_detail.dart';
import 'package:vendor_box/services/sevice.dart';

class VendorChatPage extends StatelessWidget {
  const VendorChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> _vendorChatStream = firestore
        .collection('chats')
        .where('vendorId', isEqualTo: auth.currentUser!.uid)
        .snapshots();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Message',
          style: styles(fontSize: 22.sp, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _vendorChatStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return const Text('Something went wrong');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          Map<String, String> lastProductBuyerId = {};
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot documentSnapshot = snapshot.data!.docs[index];

              Map<String, dynamic> data =
                  documentSnapshot.data()! as Map<String, dynamic>;

              String message = data['message'].toString();
              String senderId = data['senderId'].toString();
              String proId = data['proId'].toString();

              bool isSellerMessage = senderId == auth.currentUser!.uid;

              if (!isSellerMessage) {
                String key = '${senderId}_$proId';
                if (!lastProductBuyerId.containsKey(key)) {
                  lastProductBuyerId[key] = proId;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatdetailPage(
                            buyerId: data['buyerId'],
                            vendorId: auth.currentUser!.uid,
                            proId: proId,
                            data: data,
                          ),
                        ),
                      );
                    },
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              left: 12.w,
                              top: 6.h,
                              bottom: 12.h,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20.r,
                                  backgroundImage: NetworkImage(
                                    data['buyerPhoto'],
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.only(left: 12.w),
                                  padding: EdgeInsets.only(
                                    left: 12.w,
                                    right: 12.w,
                                    top: 12.h,
                                    bottom: 6.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(20.r),
                                      bottomRight: Radius.circular(20.r),
                                      topRight: Radius.circular(20.r),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message,
                                        style: styles(
                                          color: Colors.white,
                                          letterSpacing: 1,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      8.w.verticalSpace,
                                      Text(
                                        DateFormat(
                                          'dd/MM/yy kk:mm',
                                        ).format(data['chatDate'].toDate()),
                                        textAlign: TextAlign.center,
                                        style: styles(
                                          fontSize: 11.sp,
                                          height: 1.2,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Padding(
                          //   padding: EdgeInsets.only(left: 70.w),
                          //   child: Text('Sent by $senderType'),
                          // ),
                        ],
                      ),
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}
