// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/pages/chat_detail.dart';
import 'package:vendor_box/services/sevice.dart';

class BuyerDetailsWidget extends StatelessWidget {
  final String buyerId;
  final Map orderData;
  final List<Map<String, dynamic>> items;
  final String orderId;
  final Function(String, String) onMarkRead;

  const BuyerDetailsWidget({
    super.key,
    required this.buyerId,
    required this.orderData,
    required this.items,
    required this.orderId,
    required this.onMarkRead,
  });

  Widget _buildUnreadBadge(int unreadCount) {
    if (unreadCount == 0) return const SizedBox.shrink();
    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: unreadCount > 9 ? 4.w : 2.w,
          vertical: 2.h,
        ),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          unreadCount > 99 ? '99+' : '$unreadCount',
          style: styles(
            fontSize: unreadCount > 9 ? 9.sp : 10.sp,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderEmail = orderData['custemail']?.toString() ?? '';
    final orderBuyerImage = orderData['buyerImage']?.toString() ?? '';
    final orderPhone = orderData['custphone']?.toString() ?? '';
    final orderAddress = orderData['address']?.toString() ?? '';
    final orderFullName = orderData['fullName']?.toString() ?? 'Unknown Buyer';
    final defaultAvatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(orderFullName)}&background=ff6b35&color=fff&size=128';

    final String firstProId = items.isNotEmpty
        ? items.first['proId']?.toString() ?? ''
        : '';

    print(
      '=== DEBUG BADGE INPUT === Order $orderId: buyerId="$buyerId", firstProId="$firstProId", items count=${items.length}',
    );

    return GestureDetector(
      onTap: () async {
        if (items.isNotEmpty && firstProId.isNotEmpty) {
          await onMarkRead(buyerId, firstProId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatdetailPage(
                buyerId: buyerId,
                vendorId: auth.currentUser!.uid,
                proId: firstProId,
                data: orderData,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไม่พบข้อมูลสินค้าเพื่อเริ่มแชท'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: buyerId.isNotEmpty
            ? FirebaseFirestore.instance.collection('buyers').doc(buyerId).get()
            : null,
        builder: (context, buyerSnapshot) {
          String email = orderEmail.isNotEmpty ? orderEmail : 'N/A';
          String buyerImageUrl =
              orderBuyerImage.isNotEmpty && orderBuyerImage != 'null'
              ? orderBuyerImage
              : defaultAvatarUrl;

          if (buyerSnapshot.connectionState == ConnectionState.done) {
            if (buyerSnapshot.hasData && buyerSnapshot.data!.exists) {
              final buyerData =
                  buyerSnapshot.data!.data() ?? <String, dynamic>{};
              email = buyerData['email']?.toString() ?? email;
              final buyerDocImage = buyerData['image']?.toString();
              if (buyerDocImage != null &&
                  buyerDocImage.isNotEmpty &&
                  buyerDocImage != 'null')
                buyerImageUrl = buyerDocImage;
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: firstProId.isNotEmpty && buyerId.isNotEmpty
                ? firestore
                      .collection('chats')
                      .where('vendorId', isEqualTo: auth.currentUser!.uid)
                      .where('buyerId', isEqualTo: buyerId)
                      .where('proId', isEqualTo: firstProId)
                      .where('senderId', isEqualTo: buyerId)
                      .where('read', isEqualTo: false)
                      .snapshots()
                : null,
            builder: (context, chatSnapshot) {
              int unreadCount = 0;
              print(
                '=== DEBUG UNREAD STREAM === Order $orderId: State=${chatSnapshot.connectionState}, HasData=${chatSnapshot.hasData}, HasError=${chatSnapshot.hasError}',
              );

              if (chatSnapshot.hasError) {
                print('=== DEBUG UNREAD ERROR === ${chatSnapshot.error}');
                unreadCount = -1; // Flag for error state
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Chat query error (check index): ${chatSnapshot.error}',
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                });
              } else if (chatSnapshot.hasData) {
                unreadCount = chatSnapshot.data!.docs.length;
                print(
                  '=== DEBUG UNREAD COUNT === Order $orderId: Found $unreadCount docs. Sample doc IDs: ${chatSnapshot.data!.docs.take(2).map((d) => d.id).toList()}',
                );
              } else if (firstProId.isEmpty || buyerId.isEmpty) {
                print(
                  '=== DEBUG UNREAD WARNING === Order $orderId: Stream null - proId="$firstProId", buyerId="$buyerId"',
                );
              }

              Widget avatarWithBadge;
              if (unreadCount == -1) {
                // Error badge (orange warning)
                avatarWithBadge = Stack(
                  children: [
                    CircleAvatar(
                      radius: 20.r,
                      backgroundImage: buyerImageUrl.isNotEmpty
                          ? NetworkImage(buyerImageUrl)
                          : null,
                      backgroundColor: Colors.grey.shade200,
                      child: buyerImageUrl.isEmpty
                          ? Icon(Icons.person, size: 20.r, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.warning,
                          size: 12.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                avatarWithBadge = Stack(
                  children: [
                    CircleAvatar(
                      radius: 20.r,
                      backgroundImage: buyerImageUrl.isNotEmpty
                          ? NetworkImage(buyerImageUrl)
                          : null,
                      backgroundColor: Colors.grey.shade200,
                      child: buyerImageUrl.isEmpty
                          ? Icon(Icons.person, size: 20.r, color: Colors.grey)
                          : null,
                    ),
                    _buildUnreadBadge(unreadCount),
                  ],
                );
              }

              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(50),
                  border: Border(
                    top: BorderSide(color: Colors.orange.shade200),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ข้อมูลผู้สั่งซื้อ',
                      style: styles(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        avatarWithBadge,
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                orderFullName,
                                style: styles(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              if (orderAddress.isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  orderAddress,
                                  style: styles(
                                    fontSize: 12.sp,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                              if (orderPhone.isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 16.sp,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 4.w),
                                    Expanded(
                                      child: Text(
                                        orderPhone,
                                        style: styles(
                                          fontSize: 12.sp,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (email != 'N/A') ...[
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.email,
                                      size: 16.sp,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 4.w),
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: styles(
                                          fontSize: 12.sp,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (orderPhone.isEmpty) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  'No contact details available',
                                  style: styles(
                                    fontSize: 12.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
