// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/pages/chat_detail.dart';

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
  ) => [
    SlidableAction(
      flex: 3,
      onPressed: (context) => orderCancelRequested
          ? _approveOrderCancel(orderId, itemsRaw)
          : _vendorCancelOrder(orderId, itemsRaw),
      backgroundColor: const Color(0xFFFE4A49),
      foregroundColor: Colors.grey.shade100,
      icon: Icons.cancel,
      label: orderCancelRequested ? 'Approve Order Cancel' : 'Cancel Order',
    ),
  ];

  Widget _buildTitle(
    ({IconData icon, Color color, String label}) serviceDetails,
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
                Row(
                  children: [
                    Icon(
                      serviceDetails.icon,
                      size: 34.w,
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
    EasyLoading.show(status: 'Approving order cancel...');
    try {
      await _updateOrderCancel(orderId, itemsRaw, isApprove: true);
      Fluttertoast.showToast(
        msg: 'Order cancel approved',
        backgroundColor: Colors.orange,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Approve order cancel failed: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> _vendorCancelOrder(String orderId, List itemsRaw) async {
    EasyLoading.show(status: 'Cancelling order...');
    try {
      await _updateOrderCancel(orderId, itemsRaw, isApprove: false);
      Fluttertoast.showToast(
        msg: 'Order cancelled by vendor',
        backgroundColor: Colors.orange,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Order cancel failed: $e',
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
        final List itemsList = List.from(data['items'] ?? []);
        for (int i = 0; i < itemsList.length; i++) {
          final it = Map<String, dynamic>.from(itemsList[i]);
          if (!(it['accepted'] ?? false) && !(it['cancelled'] ?? false)) {
            it['cancelled'] = true;
            if (isApprove) it['cancelRequested'] = false;
            itemsList[i] = it;
          }
        }
        final updates = {'status': 'cancelled', 'items': itemsList};
        if (isApprove) updates['orderCancelRequested'] = false;
        tx.update(docRef, updates);
      }
    });
  }
}

class PreparingItemWidget extends StatelessWidget {
  final Map<String, dynamic> item;
  final String orderId;
  final List itemsRaw;
  final int uiIndex;
  final double width;

  const PreparingItemWidget({
    super.key,
    required this.item,
    required this.orderId,
    required this.itemsRaw,
    required this.uiIndex,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final rawIndex = item['__rawIndex'] as int;
    final itemCancelRequested = item['cancelRequested'] ?? false;
    final proName = item['proName']?.toString() ?? '';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final optionPrice = (item['extraPrice'] as num?)?.toDouble();
    final extraPrice =
        ((item['extraPrice'] as num?)?.toDouble() ?? 0.0) * quantity;
    final productSize = item['productSize']?.toString() ?? '';
    final selectedOptions = (item['selectedOptions'] ?? [])
        .map((opt) => Map<String, dynamic>.from(opt ?? {}))
        .toList();
    final optionsText = selectedOptions
        .map(
          (opt) =>
              '${opt['name']?.toString()} (+฿${(opt['price'] as num?)?.toDouble() ?? 0})',
        )
        .join(', ');
    final itemSubtotal = (price) * quantity;
    final itemId = item['proId']?.toString() ?? 'unknown';
    final productImage = (item['imageUrl'] as List?)?.isNotEmpty == true
        ? item['imageUrl'].first.toString()
        : '';

    print(
      '=== DEBUG ITEM BUILD === Order $orderId, UI Index: $uiIndex, Raw Index: $rawIndex, Item: $proName',
    );

    final actions = _buildActions(rawIndex, itemCancelRequested, proName);

    return Container(
      key: ValueKey('$orderId-$itemId-$rawIndex'),
      margin: EdgeInsets.only(bottom: 8.h),
      child: Slidable(
        closeOnScroll: true,
        direction: Axis.horizontal,
        startActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: actions,
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(productImage, itemCancelRequested),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildItemDetails(
                      proName,
                      productSize,
                      optionsText,
                      price,
                      quantity,
                      itemSubtotal,
                      optionPrice,
                      extraPrice,
                      itemCancelRequested,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(
    int rawIndex,
    bool itemCancelRequested,
    String proName,
  ) {
    if (itemCancelRequested) {
      return [
        SlidableAction(
          flex: 2,
          onPressed: (context) =>
              _handleApproveCancel(orderId, rawIndex, proName),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: Icons.check,
          label: 'Cancel',
        ),
        SlidableAction(
          flex: 2,
          onPressed: (context) => _handleAccept(orderId, rawIndex, proName),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          icon: Icons.check,
          label: 'Accept',
        ),
      ];
    } else {
      return [
        SlidableAction(
          flex: 2,
          onPressed: (context) => _handleAccept(orderId, rawIndex, proName),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          icon: Icons.check,
          label: 'Accept',
        ),
        SlidableAction(
          flex: 2,
          onPressed: (context) => _handleCancel(orderId, rawIndex, proName),
          backgroundColor: const Color(0xFFFE4A49),
          foregroundColor: Colors.white,
          icon: Icons.close,
          label: 'Cancel',
        ),
      ];
    }
  }

  Widget _buildImage(String productImage, bool itemCancelRequested) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            width: 60.w,
            height: 60.h,
            color: Colors.grey.shade200,
            child: productImage.isNotEmpty
                ? Image.network(
                    productImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.image_not_supported, color: Colors.grey),
                  )
                : Icon(Icons.image, color: Colors.grey),
          ),
        ),
        if (itemCancelRequested) ...[
          Container(
            height: 40.w,
            width: 40.w,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(50.r),
            ),
            child: Icon(Icons.hourglass_top, color: Colors.red, size: 24.sp),
          ),
        ],
      ],
    );
  }

  Widget _buildItemDetails(
    String proName,
    String productSize,
    String optionsText,
    double price,
    int quantity,
    double itemSubtotal,
    double? optionPrice,
    double? extraPrice,
    bool itemCancelRequested,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          proName,
          style: styles(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        if (productSize.isNotEmpty) ...[
          SizedBox(height: 2.h),
          Text(
            'Size: $productSize',
            style: styles(fontSize: 12.sp, color: Colors.black45),
          ),
        ],
        if (optionsText.isNotEmpty) ...[
          SizedBox(height: 2.h),
          Text(
            optionsText,
            style: styles(fontSize: 11.sp, color: Colors.black45),
          ),
        ],
        SizedBox(height: 4.h),
        Row(
          children: [
            Text(
              '฿${price.toStringAsFixed(2)} x $quantity',
              style: styles(fontSize: 12.sp, color: Colors.black45),
            ),
            Spacer(),
            Text(
              '= ฿${itemSubtotal.toStringAsFixed(2)}',
              style: styles(
                fontSize: 13.sp,
                color: Colors.deepOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (extraPrice != null && extraPrice > 0) ...[
          Row(
            children: [
              Text(
                'Extra: ฿$optionPrice x $quantity',
                style: styles(fontSize: 12.sp, color: Colors.orange),
              ),
              Spacer(),
              Text(
                '= ฿${extraPrice.toStringAsFixed(2)}',
                style: styles(fontSize: 12.sp, color: Colors.orange),
              ),
            ],
          ),
        ],
        if (itemCancelRequested) ...[
          Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Row(
              children: [
                Icon(Icons.hourglass_top, size: 20.sp, color: Colors.red),
                SizedBox(width: 4.w),
                Text(
                  'ขอยกเลิกรายการนี้',
                  style: styles(fontSize: 12.sp, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleAccept(
    String orderId,
    int rawIndex,
    String proName,
  ) async {
    print(
      '=== DEBUG ACCEPT PRESSED === Order $orderId, Raw Index $rawIndex, Item: $proName',
    );
    if (rawIndex < 0 || rawIndex >= itemsRaw.length) {
      Fluttertoast.showToast(msg: 'Invalid item index: $rawIndex');
      return;
    }
    bool orderDelivered = false;
    try {
      await firestore.runTransaction(
        (tx) async =>
            orderDelivered = await _processAccept(tx, orderId, rawIndex),
      );
      Fluttertoast.showToast(
        msg: orderDelivered
            ? 'Order delivered! All items accepted.'
            : 'Item accepted and ready for delivery',
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Accept failed: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _handleApproveCancel(
    String orderId,
    int rawIndex,
    String proName,
  ) async {
    print(
      '=== DEBUG APPROVE CANCEL PRESSED === Order $orderId, Raw Index $rawIndex, Item: $proName',
    );
    if (rawIndex < 0 || rawIndex >= itemsRaw.length) {
      Fluttertoast.showToast(msg: 'Invalid item index: $rawIndex');
      return;
    }
    EasyLoading.show(status: 'Approving cancel...');
    try {
      await _processCancel(orderId, rawIndex, isApprove: true);
      Fluttertoast.showToast(
        msg: 'Item cancel approved',
        backgroundColor: Colors.orange,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Approve cancel failed: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> _handleCancel(
    String orderId,
    int rawIndex,
    String proName,
  ) async {
    print(
      '=== DEBUG VENDOR CANCEL PRESSED === Order $orderId, Raw Index $rawIndex, Item: $proName',
    );
    if (rawIndex < 0 || rawIndex >= itemsRaw.length) {
      Fluttertoast.showToast(msg: 'Invalid item index: $rawIndex');
      return;
    }
    EasyLoading.show(status: 'Cancelling item...');
    try {
      await _processCancel(orderId, rawIndex, isApprove: false);
      Fluttertoast.showToast(
        msg: 'Item cancelled by vendor',
        backgroundColor: Colors.orange,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Cancel failed: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<bool> _processAccept(
    Transaction tx,
    String orderId,
    int rawIndex,
  ) async {
    final docRef = firestore.collection('orders').doc(orderId);
    final snap = await tx.get(docRef);
    if (!snap.exists) throw Exception('Order not found');

    final data = snap.data() as Map;
    final itemsList = List.from(data['items'] ?? []);
    final serviceType = data['serviceType']?.toString() ?? 'pickup';
    final shippingCharge = (data['shippingCharge'] as num?)?.toDouble() ?? 0.0;

    if (rawIndex >= 0 && rawIndex < itemsList.length) {
      final targetItem = Map<String, dynamic>.from(itemsList[rawIndex]);
      targetItem['cancelRequested'] = false;
      targetItem['accepted'] = true;
      itemsList[rawIndex] = targetItem;

      // Deduct stock
      final proId = targetItem['proId']?.toString() ?? '';
      final iQty = (targetItem['quantity'] as num?)?.toInt() ?? 1;
      if (proId.isNotEmpty) {
        final prodRef = FirebaseFirestore.instance
            .collection('products')
            .doc(proId);
        final prodSnap = await tx.get(prodRef);
        if (prodSnap.exists) {
          final pqty = (prodSnap.data()?['pqty'] as num? ?? 0).toInt();
          if (pqty < iQty) throw Exception('Insufficient stock');
          tx.update(prodRef, {'pqty': pqty - iQty});
        }
      }

      final (newPendingSubTotal, pendingCount, allAccepted) = _calcTotals(
        itemsList,
        serviceType,
        shippingCharge,
      );
      final newTotalPrice = serviceType == 'delivery'
          ? newPendingSubTotal + shippingCharge
          : newPendingSubTotal;
      final approveTime = Timestamp.now();
      final updates = {
        'items': itemsList,
        'totalPrice': newTotalPrice,
        'deliveredAt': approveTime,
      };

      if (pendingCount == 0) {
        final newStatus = allAccepted ? 'delivered' : 'cancelled';
        updates['status'] = newStatus;
        if (newStatus == 'delivered')
          updates['totalPrice'] = data['originalTotalPrice'] ?? newTotalPrice;
        tx.update(docRef, updates);
        print(
          '=== DEBUG APPROVE TIME SET === Order $orderId: deliveredAt = $approveTime',
        );
        return newStatus == 'delivered';
      }
      tx.update(docRef, updates);
      return false;
    }
    throw Exception('Invalid index $rawIndex');
  }

  Future<void> _processCancel(
    String orderId,
    int rawIndex, {
    required bool isApprove,
  }) async {
    await firestore.runTransaction((tx) async {
      final docRef = firestore.collection('orders').doc(orderId);
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Order not found');

      final data = snap.data() as Map;
      final itemsList = List.from(data['items'] ?? []);
      final serviceType = data['serviceType']?.toString() ?? 'pickup';
      final shippingCharge =
          (data['shippingCharge'] as num?)?.toDouble() ?? 0.0;

      if (rawIndex >= 0 && rawIndex < itemsList.length) {
        final targetItem = Map<String, dynamic>.from(itemsList[rawIndex]);
        targetItem['cancelled'] = true;
        if (isApprove) targetItem['cancelRequested'] = false;
        itemsList[rawIndex] = targetItem;

        final (newPendingSubTotal, pendingCount, allAccepted) = _calcTotals(
          itemsList,
          serviceType,
          shippingCharge,
        );
        final newTotalPrice = serviceType == 'delivery'
            ? newPendingSubTotal + shippingCharge
            : newPendingSubTotal;
        final updates = {'items': itemsList, 'totalPrice': newTotalPrice};

        if (pendingCount == 0) {
          final newStatus = allAccepted ? 'delivered' : 'cancelled';
          updates['status'] = newStatus;
        }
        tx.update(docRef, updates);
      } else {
        throw Exception('Invalid index $rawIndex');
      }
    });
  }

  (double, int, bool) _calcTotals(
    List itemsList,
    String serviceType,
    double shippingCharge,
  ) {
    double subTotal = 0.0;
    int pendingCount = 0;
    bool allAccepted = true;
    for (final it in itemsList) {
      final accepted = it['accepted'] ?? false;
      final cancelled = it['cancelled'] ?? false;
      if (!accepted && !cancelled) {
        final itPrice = (it['price'] as num?)?.toDouble() ?? 0.0;
        final itExtra = (it['extraPrice'] as num?)?.toDouble() ?? 0.0;
        final itQty = (it['quantity'] as num?)?.toInt() ?? 1;
        subTotal += (itPrice + itExtra) * itQty;
        pendingCount++;
      }
      if (!accepted) allAccepted = false;
    }
    return (subTotal, pendingCount, allAccepted);
  }
}

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
