// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/pages/order_tab.dart/buyer_details_widget.dart';
import 'package:vendor_box/pages/order_tab.dart/preparing_item_widget.dart';

class Preparing extends StatefulWidget {
  const Preparing({super.key});

  @override
  State<Preparing> createState() => _PreparingState();
}

class _PreparingState extends State<Preparing> {
  final Set<String> _expandedOrders = {};

  // Function to mark all unread chats as read for a specific buyer/proId
  Future<void> _markChatsAsRead({
    required String buyerId,
    required String proId,
  }) async {
    try {
      print('=== DEBUG MARK READ START === Buyer: $buyerId, Pro: $proId');
      final batch = firestore.batch();
      final unreadQuery = firestore
          .collection('chats')
          .where('vendorId', isEqualTo: auth.currentUser!.uid)
          .where('buyerId', isEqualTo: buyerId)
          .where('proId', isEqualTo: proId)
          .where('senderId', isEqualTo: buyerId)
          .where('read', isEqualTo: false);

      final unreadSnapshot = await unreadQuery.get();
      print(
        '=== DEBUG MARK READ QUERY === Found ${unreadSnapshot.docs.length} unread messages',
      );
      for (var doc in unreadSnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
      print(
        '=== DEBUG MARK READ SUCCESS === Marked ${unreadSnapshot.docs.length} messages as read',
      );
    } catch (e) {
      print('=== DEBUG MARK READ ERROR === Error marking chats as read: $e');
    }
  }

  (
    double pendingSubTotal,
    int pendingItemCount,
    int pendingQuantity,
    double acceptedSubTotal,
    int acceptedItemCount,
    int acceptedQuantity,
  )
  _calcTotals(List itemsList, String serviceType) {
    double pendingSubTotal = 0.0;
    int pendingItemCount = 0;
    int pendingQuantity = 0;
    double acceptedSubTotal = 0.0;
    int acceptedItemCount = 0;
    int acceptedQuantity = 0;
    for (final it in itemsList) {
      final accepted = it['accepted'] ?? false;
      final cancelled = it['cancelled'] ?? false;
      final itPrice = (it['price'] as num?)?.toDouble() ?? 0.0;
      final itExtra = (it['extraPrice'] as num?)?.toDouble() ?? 0.0;
      final itQty = (it['quantity'] as num?)?.toInt() ?? 1;
      if (!accepted && !cancelled) {
        pendingSubTotal += (itPrice + itExtra) * itQty;
        pendingItemCount++;
        pendingQuantity += itQty;
      }
      if (accepted) {
        acceptedSubTotal += (itPrice + itExtra) * itQty;
        acceptedItemCount++;
        acceptedQuantity += itQty;
      }
    }
    return (
      pendingSubTotal,
      pendingItemCount,
      pendingQuantity,
      acceptedSubTotal,
      acceptedItemCount,
      acceptedQuantity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: auth.currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) => _buildBody(snapshot, width),
      ),
    );
  }

  Widget _buildBody(AsyncSnapshot<QuerySnapshot> snapshot, double width) {
    if (snapshot.hasError) return _buildError(snapshot.error.toString());
    if (snapshot.connectionState == ConnectionState.waiting)
      return const Center(
        child: CircularProgressIndicator(color: Colors.yellow),
      );
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmpty();

    print(
      '=== DEBUG PREPARING SNAPSHOT === Loaded ${snapshot.data!.docs.length} pending orders',
    );
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: snapshot.data!.docs.length,
      itemBuilder: (context, index) =>
          _buildOrderCard(snapshot.data!.docs[index], width),
    );
  }

  Widget _buildError(String error) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
        SizedBox(height: 16.h),
        Text(
          'เกิดข้อผิดพลาดในการโหลด Orders: $error',
          textAlign: TextAlign.center,
          style: styles(fontSize: 16.sp, color: Colors.red),
        ),
        Text(
          'กรุณาสร้าง Composite Index ใน Firebase Console',
          textAlign: TextAlign.center,
          style: styles(fontSize: 14.sp, color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Padding(
        padding: const EdgeInsets.all(30),
        child: Icon(Icons.shopping_cart_outlined, size: 100.w),
      ),
      Text(
        'No pending orders yet!',
        textAlign: TextAlign.center,
        style: styles(
          fontSize: 26.sp,
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    ],
  );

  Widget _buildOrderCard(DocumentSnapshot document, double width) {
    final orderData = document.data() as Map? ?? {};
    final orderId = document.id;
    final buyerId = orderData['buyerId']?.toString() ?? '';
    final itemsRaw = orderData['items'] ?? [];
    final items = _processItems(itemsRaw);

    if (items.isEmpty) return const SizedBox.shrink();

    final timestamp = orderData['timestamp'] as Timestamp? ?? Timestamp.now();
    final totalPrice = (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final serviceType = orderData['serviceType']?.toString() ?? 'pickup';
    final shippingCharge =
        (orderData['shippingCharge'] as num?)?.toDouble() ?? 0.0;
    final subTotal = serviceType == 'delivery'
        ? totalPrice - shippingCharge
        : totalPrice;
    final orderCancelRequested = orderData['orderCancelRequested'] ?? false;
    final pendingCount = items.length;
    final serviceDetails = _getServiceDetails(serviceType);

    _printDebug(
      orderData,
      orderId,
      itemsRaw.length,
      items.length,
      pendingCount,
      buyerId,
    );

    final expansionChildren = [
      if (items.isNotEmpty) _buildItemsSection(items, orderId, itemsRaw, width),
      _buildSummary(subTotal, shippingCharge, serviceType, totalPrice),
      BuyerDetailsWidget(
        buyerId: buyerId,
        orderData: orderData,
        items: items,
        orderId: orderId,
        onMarkRead: (buyerId, proId) =>
            _markChatsAsRead(buyerId: buyerId, proId: proId),
      ),
    ];

    final isExpanded = _expandedOrders.contains(orderId);
    final orderActions = _buildOrderActions(
      orderId,
      orderCancelRequested,
      itemsRaw,
    );

    return Slidable(
      key: ValueKey(orderId),
      enabled: !isExpanded,
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: orderActions,
      ),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        color: Colors.white,
        child: ExpansionTile(
          backgroundColor: Colors.grey.shade100,
          collapsedIconColor: Colors.transparent,
          iconColor: Colors.transparent,
          tilePadding: EdgeInsets.only(left: 8.w, right: 8.w),
          collapsedBackgroundColor: Colors.white,
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(
              () => expanded
                  ? _expandedOrders.add(orderId)
                  : _expandedOrders.remove(orderId),
            );
            Slidable.of(context)?.close();
          },
          title: _buildTitle(
            serviceDetails,
            orderCancelRequested,
            pendingCount,
            totalPrice,
            timestamp,
          ),
          childrenPadding: EdgeInsets.zero,
          children: expansionChildren,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _processItems(List itemsRaw) {
    return itemsRaw
        .asMap()
        .entries
        .where((entry) {
          final item = Map<String, dynamic>.from(entry.value ?? {});
          final isAccepted = item['accepted'] ?? false;
          final isCancelled = item['cancelled'] ?? false;
          return item.isNotEmpty && !isAccepted && !isCancelled;
        })
        .map((entry) {
          final item = Map<String, dynamic>.from(entry.value);
          item['__rawIndex'] = entry.key;
          return item;
        })
        .toList();
  }

  ({IconData icon, Color color, String label}) _getServiceDetails(
    String serviceType,
  ) => serviceType == 'delivery'
      ? (
          icon: Icons.delivery_dining,
          color: Colors.green,
          label: serviceType.toUpperCase(),
        )
      : (
          icon: Icons.store,
          color: Colors.blue,
          label: serviceType.toUpperCase(),
        );

  void _printDebug(
    Map orderData,
    String orderId,
    int rawLength,
    int filteredLength,
    int pendingCount,
    String buyerId,
  ) {
    print(
      '=== DEBUG PREPARING VENDOR NAME === Order $orderId: fallback="${orderData['bussinessName']?.toString() ?? 'Unknown Vendor'}"',
    );
    print(
      '=== DEBUG PREPARING SHIPPING === Order $orderId: serviceType="${orderData['serviceType']}", shippingCharge=${orderData['shippingCharge']}, subTotal=${orderData['totalPrice'] - (orderData['shippingCharge'] ?? 0)}, totalPrice=${orderData['totalPrice']}',
    );
    print(
      '=== DEBUG ITEMS INDEX === Order $orderId: rawLength=$rawLength, filteredItems=$filteredLength, pendingCount=$pendingCount',
    );
    print('=== DEBUG BUYER DETAILS === Order $orderId: buyerId="$buyerId"');
  }

  Widget _buildItemsSection(
    List<Map<String, dynamic>> items,
    String orderId,
    List itemsRaw,
    double width,
  ) => SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    child: Column(
      children: items
          .asMap()
          .entries
          .map(
            (e) => PreparingItemWidget(
              item: e.value,
              orderId: orderId,
              itemsRaw: itemsRaw,
              uiIndex: e.key,
              width: width,
            ),
          )
          .toList(),
    ),
  );

  Widget _buildSummary(
    double subTotal,
    double shippingCharge,
    String serviceType,
    double totalPrice,
  ) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      border: Border(
        top: BorderSide(color: Colors.grey.shade300),
        bottom: BorderSide(color: Colors.grey.shade300),
      ),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ยอดรวมสินค้า',
              style: styles(fontSize: 14.sp, color: Colors.black54),
            ),
            Text(
              '฿${subTotal.toStringAsFixed(2)}',
              style: styles(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        if (serviceType == 'delivery') ...[
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ค่าส่ง',
                style: styles(fontSize: 14.sp, color: Colors.black54),
              ),
              Text(
                '฿${shippingCharge.toStringAsFixed(2)}',
                style: styles(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: 20.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'รวมทั้งหมด',
              style: styles(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '฿${totalPrice.toStringAsFixed(2)}',
              style: styles(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  List<Widget> _buildOrderActions(
    String orderId,
    bool orderCancelRequested,
    List itemsRaw,
  ) {
    if (orderCancelRequested) {
      return [
        SlidableAction(
          flex: 3,
          onPressed: (context) => _approveOrderCancel(orderId, itemsRaw),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: Icons.check,
          label: 'ยกเลิกตามคำขอ',
        ),
        SlidableAction(
          flex: 3,
          onPressed: (context) => _rejectOrderCancel(orderId, itemsRaw),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          icon: Icons.close,
          label: 'ไม่สามารถยกเลิกได้',
        ),
      ];
    } else {
      return [
        SlidableAction(
          flex: 3,
          onPressed: (context) => _vendorCancelOrder(orderId, itemsRaw),
          backgroundColor: const Color(0xFFFE4A49),
          foregroundColor: Colors.white,
          icon: Icons.cancel,
          label: 'ยกเลิกคำสั่งซื้อ',
        ),
      ];
    }
  }

  Widget _buildTitle(
    ({IconData icon, Color color, String label}) serviceDetails,
    bool orderCancelRequested,
    int pendingCount,
    double totalPrice,
    Timestamp timestamp,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: 6.h),
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                orderCancelRequested
                    ? Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20.r),
                          color: Colors.red.shade400,
                        ),
                        child: Text(
                          'ขอยกเลิกคำสั่งซื้อทั้งหมด',
                          style: styles(
                            fontSize: 13.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            serviceDetails.icon,
                            size: 20.w,
                            color: serviceDetails.color,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            serviceDetails.label,
                            style: styles(
                              fontSize: 12.sp,
                              color: serviceDetails.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                Text(
                  '$pendingCount รายการ',
                  style: styles(fontSize: 12.sp, color: Colors.black54),
                ),
                SizedBox(height: 4.h),
                Text(
                  '฿${totalPrice.toStringAsFixed(2)}',
                  style: styles(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  DateFormat('dd/MM/yy - kk:mm').format(timestamp.toDate()),
                  style: styles(fontSize: 10.sp, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: 4.h),
    ],
  );

  Future<void> _approveOrderCancel(String orderId, List itemsRaw) async {
    EasyLoading.show(status: 'กำลังอนุมัติการยกเลิก...');
    try {
      await _updateOrderCancel(orderId, itemsRaw, isApprove: true);
      Fluttertoast.showToast(
        msg: 'อนุมัติการยกเลิกคำสั่งซื้อแล้ว',
        backgroundColor: Colors.orange,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'อนุมัติการยกเลิกล้มเหลว: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> _rejectOrderCancel(String orderId, List itemsRaw) async {
    EasyLoading.show(status: 'กำลังปฏิเสธคำขอยกเลิก...');
    try {
      await _processRejectCancel(orderId, itemsRaw);
      Fluttertoast.showToast(
        msg: 'ปฏิเสธคำขอยกเลิกและยืนยันคำสั่งซื้อแล้ว',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'ปฏิเสธคำขอยกเลิกล้มเหลว: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> _vendorCancelOrder(String orderId, List itemsRaw) async {
    EasyLoading.show(status: 'กำลังยกเลิกคำสั่งซื้อ...');
    try {
      await _updateOrderCancel(orderId, itemsRaw, isApprove: false);
      Fluttertoast.showToast(
        msg: 'ยกเลิกคำสั่งซื้อโดยผู้ขายแล้ว',
        backgroundColor: Colors.orange,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'ยกเลิกคำสั่งซื้อล้มเหลว: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> _updateOrderCancel(
  String orderId,
  List itemsRaw, {
  required bool isApprove,
}) async {
  await firestore.runTransaction((tx) async {
    final docRef = firestore.collection('orders').doc(orderId);
    final snap = await tx.get(docRef);
    if (snap.exists) {
      final data = snap.data() as Map;
      final itemsList = List.from(data['items'] ?? []);
      final serviceType = data['serviceType']?.toString() ?? 'pickup';
      final originalShippingCharge = (data['shippingCharge'] as num?)?.toDouble() ?? 0.0;  // FIXED: Use original shipping

      for (int i = 0; i < itemsList.length; i++) {
        final it = Map<String, dynamic>.from(itemsList[i]);
        if (!(it['accepted'] ?? false) && !(it['cancelled'] ?? false)) {
          it['cancelled'] = true;
          if (isApprove) it['cancelRequested'] = false;
          itemsList[i] = it;
        }
      }

      final (
        pendingSubTotal,
        pendingItemCount,
        pendingQuantity,
        acceptedSubTotal,
        acceptedItemCount,
        acceptedQuantity,
      ) = _calcTotals(
        itemsList,
        serviceType,
      );

      // FIXED: Use original shipping for pending total
      final newPendingTotal = pendingSubTotal + originalShippingCharge;

      Map<String, dynamic> updates = {
        'items': itemsList,
        'totalPrice': newPendingTotal,
        // REMOVED: 'shippingCharge': newShipping (keep original)
      };
      if (isApprove) updates['orderCancelRequested'] = false;

      if (pendingItemCount == 0) {
        if (acceptedItemCount > 0) {
          // FIXED: Use original shipping for delivered total
          final deliveredTotal = acceptedSubTotal + originalShippingCharge;
          updates['status'] = 'delivered';
          updates['totalPrice'] = deliveredTotal;
          // REMOVED: 'shippingCharge': deliveredShipping (keep original)
          updates['deliveredAt'] = Timestamp.now();
        } else {
          updates['status'] = 'cancelled';
          updates['totalPrice'] = 0.0;
          // REMOVED: 'shippingCharge': 0.0 (keep original)
        }
      } else {
        updates['status'] = 'pending';
      }

      tx.update(docRef, updates);
    }
  });
}

Future<void> _processRejectCancel(String orderId, List itemsRaw) async {
  await firestore.runTransaction((tx) async {
    final docRef = firestore.collection('orders').doc(orderId);
    final snap = await tx.get(docRef);
    if (!snap.exists) throw Exception('Order not found');

    final data = snap.data() as Map;
    final itemsList = List.from(data['items'] ?? []);
    final serviceType = data['serviceType']?.toString() ?? 'pickup';
    final originalShippingCharge = (data['shippingCharge'] as num?)?.toDouble() ?? 0.0;  // FIXED: Use original shipping

    bool insufficientStock = false;
    for (int i = 0; i < itemsList.length; i++) {
      final it = Map<String, dynamic>.from(itemsList[i]);
      final accepted = it['accepted'] ?? false;
      final cancelled = it['cancelled'] ?? false;
      if (!accepted && !cancelled) {
        // Accept the item
        it['accepted'] = true;
        it['cancelRequested'] = false;

        // Deduct stock
        final proId = it['proId']?.toString() ?? '';
        final iQty = (it['quantity'] as num?)?.toInt() ?? 1;
        if (proId.isNotEmpty && iQty > 0) {
          final prodRef = firestore.collection('products').doc(proId);
          final prodSnap = await tx.get(prodRef);
          if (prodSnap.exists) {
            final pqty = (prodSnap.data()?['pqty'] as num? ?? 0).toInt();
            if (pqty < iQty) {
              insufficientStock = true;
              break;
            }
            tx.update(prodRef, {'pqty': pqty - iQty});
          }
        }
        itemsList[i] = it;
      }
    }

    if (insufficientStock) {
      throw Exception('สินค้าบางรายการสต็อกไม่พอ');
    }

    // Calculate full subtotal for all accepted items
    final (
      pendingSubTotal,
      pendingItemCount,
      pendingQuantity,
      acceptedSubTotal,
      acceptedItemCount,
      acceptedQuantity,
    ) = _calcTotals(
      itemsList,
      serviceType,
    );

    // FIXED: Use original shipping for full total
    final fullTotalPrice = acceptedSubTotal + originalShippingCharge;

    // Since all pending are now accepted, set to delivered
    final updates = {
      'items': itemsList,
      'orderCancelRequested': false,
      'status': 'delivered',
      'deliveredAt': Timestamp.now(),
      'totalPrice': fullTotalPrice,
      // REMOVED: 'shippingCharge': newShipping (keep original)
    };

    tx.update(docRef, updates);
    print(
      '=== DEBUG REJECT CANCEL SUCCESS === Order $orderId: Set to delivered',
    );
  });
}}
