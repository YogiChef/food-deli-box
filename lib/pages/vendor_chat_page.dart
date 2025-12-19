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
        .orderBy('chatDate', descending: true)
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

          // FIXED: Group by buyerId + proId to show unique chats (last message only)
          Map<String, DocumentSnapshot> lastChats = {};
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['senderId'] != auth.currentUser!.uid) {
              // Only buyer messages
              final key = '${data['buyerId']}_${data['proId']}';
              lastChats[key] = doc;
            }
          }

          return ListView.separated(
            itemCount: lastChats.length,
            separatorBuilder: (context, index) => Divider(height: 1.h),
            itemBuilder: (context, index) {
              final entry = lastChats.entries.elementAt(index);
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;
              final String proId = data['proId'];
              final String buyerId = data['buyerId'];
              final String messageType = data['messageType'] ?? 'text';
              final String? imageUrl =
                  data['imageUrl']; // FIXED: Check imageUrl
              // FIXED: Handle 'slip' preview
              final String preview = messageType == 'slip'
                  ? 'สลิปการชำระเงิน'
                  : (messageType == 'image' && imageUrl != null
                        ? '📷 รูปภาพ'
                        : data['message']);

              return ListTile(
                leading: CircleAvatar(
                  radius: 20.r,
                  backgroundImage: NetworkImage(data['buyerPhoto'] ?? ''),
                  onBackgroundImageError: (_, __) => Icon(Icons.person),
                ),
                title: Text(
                  'Order #${proId.substring(0, 8)}',
                ), // Or use proName from data
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.length > 50
                          ? '${preview.substring(0, 50)}...'
                          : preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // FIXED: Show small image for both 'image' and 'slip'
                    if ((messageType == 'image' || messageType == 'slip') &&
                        imageUrl != null)
                      SizedBox(
                        height: 60.h,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              Icon(Icons.broken_image, size: 20.r),
                        ),
                      ),
                  ],
                ),
                trailing: Text(
                  DateFormat('HH:mm').format(data['chatDate'].toDate()),
                  style: styles(fontSize: 12.sp, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatdetailPage(
                        buyerId: buyerId,
                        vendorId: auth.currentUser!.uid,
                        proId: proId,
                        data: data,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
