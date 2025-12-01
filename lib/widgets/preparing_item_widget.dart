// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vendor_box/services/sevice.dart';

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
            width: 50.w,
            height: 40.h,
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
            width: 50.w,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Icon(Icons.hourglass_top, color: Colors.white, size: 24.sp),
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

      final (pendingSubTotal, pendingCount, acceptedSubTotal, acceptedCount) =
          _calcTotals(itemsList, serviceType, shippingCharge);
      final newPendingTotal = serviceType == 'delivery'
          ? pendingSubTotal + shippingCharge
          : pendingSubTotal;
      final approveTime = Timestamp.now();
      final updates = {'items': itemsList, 'totalPrice': newPendingTotal};

      if (pendingCount == 0) {
        if (acceptedCount > 0) {
          final deliveredTotal = serviceType == 'delivery'
              ? acceptedSubTotal + shippingCharge
              : acceptedSubTotal;
          updates['status'] = 'delivered';
          updates['totalPrice'] = deliveredTotal;
          updates['deliveredAt'] = approveTime;
          tx.update(docRef, updates);
          print(
            '=== DEBUG APPROVE TIME SET === Order $orderId: deliveredAt = $approveTime',
          );
          return true;
        } else {
          updates['status'] = 'cancelled';
          updates['totalPrice'] = 0.0;
          tx.update(docRef, updates);
          return false;
        }
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

        final (pendingSubTotal, pendingCount, acceptedSubTotal, acceptedCount) =
            _calcTotals(itemsList, serviceType, shippingCharge);
        final newPendingTotal = serviceType == 'delivery'
            ? pendingSubTotal + shippingCharge
            : pendingSubTotal;
        final updates = {'items': itemsList, 'totalPrice': newPendingTotal};

        if (pendingCount == 0) {
          if (acceptedCount > 0) {
            final deliveredTotal = serviceType == 'delivery'
                ? acceptedSubTotal + shippingCharge
                : acceptedSubTotal;
            updates['status'] = 'delivered';
            updates['totalPrice'] = deliveredTotal;
            updates['deliveredAt'] = Timestamp.now();
          } else {
            updates['status'] = 'cancelled';
            updates['totalPrice'] = 0.0;
          }
        }
        tx.update(docRef, updates);
      } else {
        throw Exception('Invalid index $rawIndex');
      }
    });
  }

  (
    double pendingSubTotal,
    int pendingCount,
    double acceptedSubTotal,
    int acceptedCount,
  )
  _calcTotals(List itemsList, String serviceType, double shippingCharge) {
    double pendingSubTotal = 0.0;
    int pendingCount = 0;
    double acceptedSubTotal = 0.0;
    int acceptedCount = 0;
    for (final it in itemsList) {
      final accepted = it['accepted'] ?? false;
      final cancelled = it['cancelled'] ?? false;
      if (!accepted && !cancelled) {
        final itPrice = (it['price'] as num?)?.toDouble() ?? 0.0;
        final itExtra = (it['extraPrice'] as num?)?.toDouble() ?? 0.0;
        final itQty = (it['quantity'] as num?)?.toInt() ?? 1;
        pendingSubTotal += (itPrice + itExtra) * itQty;
        pendingCount++;
      }
      if (accepted) {
        final itPrice = (it['price'] as num?)?.toDouble() ?? 0.0;
        final itExtra = (it['extraPrice'] as num?)?.toDouble() ?? 0.0;
        final itQty = (it['quantity'] as num?)?.toInt() ?? 1;
        acceptedSubTotal += (itPrice + itExtra) * itQty;
        acceptedCount++;
      }
    }
    return (pendingSubTotal, pendingCount, acceptedSubTotal, acceptedCount);
  }
}
