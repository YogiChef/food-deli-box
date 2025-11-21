import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:vendor_box/services/sevice.dart';

class ChatdetailPage extends StatefulWidget {
  final String buyerId;
  final String vendorId;
  final String proId;
  final dynamic data;
  const ChatdetailPage({
    super.key,
    required this.vendorId,
    required this.buyerId,
    required this.proId,
    required this.data,
  });

  @override
  State<ChatdetailPage> createState() => _ChatdetailPageState();
}

class _ChatdetailPageState extends State<ChatdetailPage> {
  final _messageController = TextEditingController();
  late Stream<QuerySnapshot> _chatStream;

  @override
  void initState() {
    _chatStream = firestore
        .collection('chats')
        .where('buyerId', isEqualTo: widget.buyerId)
        .where('vendorId', isEqualTo: widget.vendorId)
        .where('proId', isEqualTo: widget.proId)
        .orderBy('chatDate', descending: true)
        .snapshots();
    super.initState();
  }

  void _sendMessage() async {
    DocumentSnapshot vendorDoc = await firestore
        .collection('vendors')
        .doc(widget.vendorId)
        .get();
    DocumentSnapshot buyerDoc = await firestore
        .collection('buyers')
        .doc(widget.buyerId)
        .get();
    String message = _messageController.text.trim();

    if (message.isNotEmpty) {
      await firestore.collection('chats').add({
        'proId': widget.proId,
        'buyerName': (buyerDoc.data() as Map<String, dynamic>)['fullName'],
        'buyerPhoto': (buyerDoc.data() as Map<String, dynamic>)['profileImage'],
        'vendorPhoto': (vendorDoc.data() as Map<String, dynamic>)['image'],
        'buyerId': widget.buyerId,
        'vendorId': widget.vendorId,
        'message': message,
        'senderId': auth.currentUser!.uid,
        'chatDate': DateTime.now(),
      });
      setState(() {
        _messageController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat Screen',
          style: styles(fontSize: 22.sp, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatStream,
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return const Text('Something went wrong');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        reverse: true,
                        children: snapshot.data!.docs.map((
                          DocumentSnapshot document,
                        ) {
                          Map<String, dynamic> data =
                              document.data()! as Map<String, dynamic>;

                          String senderId = data['senderId'];
                          // bool isBuyer = senderId == widget.buyerId;
                          // String senderType = isBuyer ? 'Buyer' : 'Seller';
                          bool isVendorMessage =
                              senderId == auth.currentUser!.uid;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  left: 12.w,
                                  bottom: 12.h,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    isVendorMessage
                                        ? const SizedBox.shrink()
                                        : CircleAvatar(
                                            radius: 16.r,
                                            backgroundImage: NetworkImage(
                                              data['buyerPhoto'],
                                            ),
                                          ),
                                    Flexible(
                                      child: isVendorMessage
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Align(
                                                  alignment:
                                                      Alignment.bottomRight,
                                                  child: Container(
                                                    clipBehavior: Clip.hardEdge,
                                                    margin: EdgeInsets.only(
                                                      right: 12.w,
                                                    ),
                                                    padding: EdgeInsets.only(
                                                      left: 12.w,
                                                      right: 12.w,
                                                      top: 12.h,
                                                      bottom: 6.h,
                                                    ),
                                                    constraints: BoxConstraints(
                                                      maxWidth: width * 0.8,
                                                      minWidth: 40.w,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.blue.shade600,
                                                      borderRadius:
                                                          BorderRadius.only(
                                                            topLeft:
                                                                Radius.circular(
                                                                  20.r,
                                                                ),
                                                            bottomLeft:
                                                                Radius.circular(
                                                                  20.r,
                                                                ),
                                                            topRight:
                                                                Radius.circular(
                                                                  20.r,
                                                                ),
                                                          ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          data['message'],
                                                          style: styles(
                                                            color: Colors.white,
                                                            fontSize: 16.sp,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                        10.w.verticalSpace,
                                                        Text(
                                                          DateFormat(
                                                            'dd/MM/yy kk:mm',
                                                          ).format(
                                                            data['chatDate']
                                                                .toDate(),
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: styles(
                                                            fontSize: 11.sp,
                                                            height: 1.2,
                                                            color:
                                                                Colors.white70,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Align(
                                                  alignment:
                                                      Alignment.bottomLeft,
                                                  child: Container(
                                                    clipBehavior: Clip.hardEdge,
                                                    margin: EdgeInsets.only(
                                                      left: 12.w,
                                                    ),
                                                    padding: EdgeInsets.only(
                                                      left: 12.w,
                                                      right: 12.w,
                                                      top: 12.h,
                                                      bottom: 6.h,
                                                    ),
                                                    constraints: BoxConstraints(
                                                      maxWidth: width * 0.8,
                                                      minWidth: 40.w,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade200,
                                                      borderRadius:
                                                          BorderRadius.only(
                                                            topLeft:
                                                                Radius.circular(
                                                                  20.r,
                                                                ),
                                                            topRight:
                                                                Radius.circular(
                                                                  20.r,
                                                                ),
                                                            bottomRight:
                                                                Radius.circular(
                                                                  20.r,
                                                                ),
                                                          ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          data['message'],
                                                          style: styles(
                                                            color:
                                                                Colors.black87,
                                                            fontSize: 16.sp,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                        10.w.verticalSpace,
                                                        Text(
                                                          DateFormat(
                                                            'dd/MM/yy kk:mm',
                                                          ).format(
                                                            data['chatDate']
                                                                .toDate(),
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: styles(
                                                            fontSize: 11.sp,
                                                            height: 1.2,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Padding(
          //   padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          //   child: Row(
          //     children: [
          //       Expanded(
          //           child: TextField(
          //         controller: _messageController,
          //         decoration: const InputDecoration(hintText: 'Type a message'),
          //       )),
          //       IconButton(
          //           onPressed: _sendMessage,
          //           icon: const Icon(
          //             Icons.send,
          //             color: Colors.indigo,
          //           ))
          //     ],
          //   ),
          // )
          70.verticalSpace,
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _messageController,
          style: styles(color: Colors.black54, fontSize: 16),
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
            hintText: 'Type a message',
            hintStyle: styles(
              color: Colors.black38,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            suffixIcon: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.blue),
            ),
            // filled: true,
            // fillColor: Colors.green,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                width: 0.5,
                color: Colors.blue,
                style: BorderStyle.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
