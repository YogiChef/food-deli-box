// Updated ChatdetailPage.dart - Added confirmation button for vendor on pending slips
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
        'proName': widget.data['proName'] ?? 'Product', // Use from passed data
        'buyerName': (buyerDoc.data() as Map<String, dynamic>)['fullName'],
        'buyerPhoto': (buyerDoc.data() as Map<String, dynamic>)['profileImage'],
        'vendorPhoto': (vendorDoc.data() as Map<String, dynamic>)['image'],
        'buyerId': widget.buyerId,
        'vendorId': widget.vendorId,
        'message': message,
        'messageType': 'text',
        'senderId': auth.currentUser!.uid,
        'chatDate': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
    }
  }

  // Updated: Add confirmSlip function
  Future<void> _confirmSlip(String chatDocId, String orderId) async {
    try {
      await firestore.collection('chats').doc(chatDocId).update({
        'slipStatus': 'confirmed',
      });
      await firestore.collection('orders').doc(orderId).update({
        'slipStatus': 'confirmed',
        'status': 'paid', // Confirm payment
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ยืนยันสลิปสำเร็จ! ออร์เดอร์ได้รับการชำระเงินแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการยืนยัน: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // FIXED: Helper to render message (text, image, or slip) with status and confirm button
  Widget _buildMessageBubble(
    Map<String, dynamic> data,
    bool isVendorMessage,
    String docId,
  ) {
    final String messageType = data['messageType'] ?? 'text';
    final String? imageUrl = data['imageUrl'];
    final String? orderId = data['orderId']; // For slip
    final DateTime chatDate = (data['chatDate'] as Timestamp).toDate();
    final String? slipStatus = data['slipStatus']; // New field

    return Container(
      // clipBehavior: Clip.hardEdge,
      // margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      // padding: EdgeInsets.all(12.w),
      constraints: BoxConstraints(maxWidth: width * 0.6, minWidth: 40.w),
      // decoration: BoxDecoration(
      //   color: isVendorMessage ? Colors.blue.shade600 : Colors.grey.shade200,
      //   borderRadius: BorderRadius.circular(6.r),
      // ),
      child: imageUrl!.isNotEmpty
          ? InkWell(
              onTap: () => _zoomSlip(imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Image.network(
                  imageUrl,
                  height: height * 0.5.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    height: 200.h,
                    color: Colors.grey.shade300,
                    child: Icon(Icons.error, color: Colors.red),
                  ),
                  loadingBuilder: (context, child, loading) => loading != null
                      ? Center(child: CircularProgressIndicator())
                      : child,
                ),
              ),
            )
          : SizedBox.shrink(),
      // child: Column(
      //   crossAxisAlignment: CrossAxisAlignment.start,
      //   mainAxisSize: MainAxisSize.min,
      //   children: [
      //     // FIXED: Conditional render for text, image, or slip
      //     if (messageType == 'slip') ...[
      //       // Handle slip type with status
      //       Row(
      //         children: [
      //           Icon(
      //             Icons.receipt,
      //             color: isVendorMessage ? Colors.amber : Colors.white70,
      //             size: 16.sp,
      //           ),
      //           SizedBox(width: 4.w),
      //           Expanded(
      //             child: Column(
      //               crossAxisAlignment: CrossAxisAlignment.start,
      //               children: [
      //                 Text(
      //                   'สลิปการชำระเงิน',
      //                   style: styles(
      //                     color: isVendorMessage
      //                         ? Colors.white
      //                         : Colors.black87,
      //                     fontSize: 14.sp,
      //                     fontWeight: FontWeight.w600,
      //                   ),
      //                 ),
      //                 if (slipStatus != null) ...[
      //                   SizedBox(height: 2.h),
      //                   Container(
      //                     padding: EdgeInsets.symmetric(
      //                       horizontal: 6.w,
      //                       vertical: 2.h,
      //                     ),
      //                     decoration: BoxDecoration(
      //                       color: slipStatus == 'pending'
      //                           ? Colors.orange.shade100
      //                           : Colors.green.shade100,
      //                       borderRadius: BorderRadius.circular(10.r),
      //                     ),
      //                     child: Text(
      //                       slipStatus == 'pending'
      //                           ? 'รอการยืนยัน'
      //                           : 'ยืนยันแล้ว',
      //                       style: TextStyle(
      //                         color: slipStatus == 'pending'
      //                             ? Colors.orange.shade800
      //                             : Colors.green.shade800,
      //                         fontSize: 10.sp,
      //                         fontWeight: FontWeight.w500,
      //                       ),
      //                     ),
      //                   ),
      //                 ],
      //               ],
      //             ),
      //           ),
      //           // Confirm button for vendor if pending and from buyer
      //           if (!isVendorMessage &&
      //               slipStatus == 'pending' &&
      //               orderId != null) ...[
      //             IconButton(
      //               onPressed: () => _confirmSlip(docId, orderId),
      //               icon: const Icon(
      //                 Icons.check_circle,
      //                 color: Colors.green,
      //                 size: 20,
      //               ),
      //               tooltip: 'ยืนยันสลิป',
      //             ),
      //           ],
      //         ],
      //       ),
      //       if (imageUrl!.isNotEmpty)
      //         ClipRRect(
      //           borderRadius: BorderRadius.circular(12.r),
      //           child: Image.network(
      //             imageUrl,
      //             height: height * 0.45.h,
      //             width: double.infinity,
      //             fit: BoxFit.cover,
      //             errorBuilder: (context, error, stack) => Container(
      //               height: 200.h,
      //               color: Colors.grey.shade300,
      //               child: Icon(Icons.error, color: Colors.red),
      //             ),
      //             loadingBuilder: (context, child, loading) => loading != null
      //                 ? Center(child: CircularProgressIndicator())
      //                 : child,
      //           ),
      //         ),
      //       if (data['message'] != null && data['message'].isNotEmpty)
      //         Text(
      //           data['message'],
      //           style: styles(
      //             color: isVendorMessage ? Colors.white70 : Colors.black54,
      //             fontSize: 12.sp,
      //           ),
      //         ),
      //     ] else if (messageType == 'text' || imageUrl == null)
      //       Text(
      //         data['message'],
      //         style: styles(
      //           color: isVendorMessage ? Colors.white : Colors.black87,
      //           fontSize: 16.sp,
      //           fontWeight: FontWeight.w400,
      //         ),
      //       )
      //     else if (messageType == 'image' && imageUrl.isNotEmpty)
      //       ClipRRect(
      //         borderRadius: BorderRadius.circular(12.r),
      //         child: Image.network(
      //           imageUrl,
      //           height: 200.h,
      //           width: double.infinity,
      //           fit: BoxFit.cover,
      //           errorBuilder: (context, error, stack) => Container(
      //             height: 200.h,
      //             color: Colors.grey.shade300,
      //             child: Icon(Icons.error, color: Colors.red),
      //           ),
      //           loadingBuilder: (context, child, loading) => loading != null
      //               ? Center(child: CircularProgressIndicator())
      //               : child,
      //         ),
      //       ),
      //     SizedBox(height: 4.h),
      //     Text(
      //       DateFormat('dd/MM/yy kk:mm').format(chatDate),
      //       style: styles(
      //         fontSize: 11.sp,
      //         color: isVendorMessage ? Colors.white70 : Colors.grey,
      //       ),
      //     ),
      //   ],
      // ),
    );
  }

  void _zoomSlip(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text('ดูสลิป')),
          body: InteractiveViewer(child: Image.network(url)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String proName =
        widget.data['proName'] ?? 'Chat Detail'; // From passed data
    return Scaffold(
      appBar: AppBar(
        title: Text(
          proName,
          style: styles(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatStream,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot> snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return const Text('Something went wrong');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView.builder(
                      reverse: false, // Bottom-aligned (new messages at bottom)
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final document = snapshot.data!.docs[index];
                        final data = document.data() as Map<String, dynamic>;
                        final bool isVendorMessage =
                            data['senderId'] == auth.currentUser!.uid;
                        final String docId = document.id; // For update

                        return Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Row(
                            mainAxisAlignment: isVendorMessage
                                ? MainAxisAlignment
                                      .end // Right-align for vendor (sender)
                                : MainAxisAlignment
                                      .start, // Left-align for buyer (receiver)
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isVendorMessage) ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: CircleAvatar(
                                    radius: 16.r,
                                    backgroundImage: NetworkImage(
                                      data['buyerPhoto'] ?? '',
                                    ),
                                    onBackgroundImageError: (_, __) =>
                                        Icon(Icons.person),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                              ],
                              _buildMessageBubble(data, isVendorMessage, docId),
                              if (isVendorMessage) ...[
                                SizedBox(width: 8.w),
                                CircleAvatar(
                                  radius: 16.r,
                                  backgroundImage: NetworkImage(
                                    data['vendorPhoto'] ?? '',
                                  ),
                                  onBackgroundImageError: (_, __) =>
                                      Icon(Icons.person),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
            ),
          ),
          70.h.verticalSpace,
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                width: 0.5,
                color: Colors.blue,
                style: BorderStyle.none,
              ),
            ),
          ),
          onFieldSubmitted: (_) => _sendMessage(),
        ),
      ),
    );
  }
}
