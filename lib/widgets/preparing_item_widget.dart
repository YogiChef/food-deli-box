// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vendor_box/services/sevice.dart';

class PreparingItemWidget extends StatefulWidget {
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
  State<PreparingItemWidget> createState() => _PreparingItemWidgetState();
}

class _PreparingItemWidgetState extends State<PreparingItemWidget>
    with TickerProviderStateMixin {
  late SlidableController _slidableController;
  bool _triggered = false;

  // State fields สำหรับค่า item (ป้องกัน stale data)
  late int rawIndex;
  late bool itemCancelRequested;
  late String proName;

  @override
  void initState() {
    super.initState();
    _updateItemData();

    _slidableController = SlidableController(this);
    _slidableController.animation.addStatusListener(_onAnimationStatusChanged);
  }

  @override
  void didUpdateWidget(covariant PreparingItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _updateItemData();
    }
  }

  void _updateItemData() {
    rawIndex = widget.item['__rawIndex'] as int;
    itemCancelRequested = widget.item['cancelRequested'] ?? false;
    proName = widget.item['proName']?.toString() ?? '';
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    print(
      '=== DEBUG ANIMATION === Status: $status, Ratio: ${_slidableController.ratio}, Triggered: $_triggered',
    );
    if (status == AnimationStatus.completed &&
        _slidableController.ratio >=
            0.5 && // <-- ปรับเป็น 0.5 เพื่อ match log ของคุณ
        !_triggered) {
      print('=== TRIGGERING DIALOG ==='); // Debug: ต้องเห็น log นี้หลัง swipe
      _triggered = true;
      _showActionDialog(
        context,
        rawIndex,
        itemCancelRequested,
        proName,
        widget.orderId,
      );
      _slidableController.close(); // Close หลัง show dialog
    } else if (status == AnimationStatus.dismissed) {
      print('=== RESET TRIGGER ===');
      _triggered = false;
    }
  }

  @override
  void dispose() {
    _slidableController.animation.removeStatusListener(
      _onAnimationStatusChanged,
    );
    _slidableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quantity = (widget.item['quantity'] as num?)?.toInt() ?? 1;
    final price = (widget.item['price'] as num?)?.toDouble() ?? 0.0;
    final optionPrice = (widget.item['extraPrice'] as num?)?.toDouble();
    final extraPrice =
        ((widget.item['extraPrice'] as num?)?.toDouble() ?? 0.0) * quantity;
    final productSize = widget.item['productSize']?.toString() ?? '';
    final selectedOptions = (widget.item['selectedOptions'] ?? [])
        .map((opt) => Map<String, dynamic>.from(opt ?? {}))
        .toList();
    final optionsText = selectedOptions
        .map(
          (opt) =>
              '${opt['name']?.toString()} (+฿${(opt['price'] as num?)?.toDouble() ?? 0})',
        )
        .join(', ');
    final itemSubtotal = price * quantity;
    final itemId = widget.item['proId']?.toString() ?? 'unknown';
    final productImage = (widget.item['imageUrl'] as List?)?.isNotEmpty == true
        ? widget.item['imageUrl'].first.toString()
        : '';

    print(
      '=== DEBUG ITEM BUILD === Order ${widget.orderId}, UI Index: ${widget.uiIndex}, Raw Index: $rawIndex, Item: $proName',
    );

    return Container(
      key: ValueKey('${widget.orderId}-$itemId-$rawIndex'),
      margin: EdgeInsets.only(bottom: 8.h),
      child: Slidable(
        controller: _slidableController,
        closeOnScroll: true,
        direction: Axis.horizontal,
        startActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [], // ว่าง OK แต่ ratio=0.5
          // Optional: ถ้าต้องการ ratio=1.0 (open เต็ม) ให้เพิ่ม dummy action นี้
          // children: [
          //   SlidableAction(
          //     onPressed: (context) {},  // ว่าง
          //     backgroundColor: Colors.transparent,
          //     foregroundColor: Colors.transparent,
          //     flex: 1,
          //   ),
          // ],
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

  Future<void> _showActionDialog(
    BuildContext context,
    int rawIndex,
    bool itemCancelRequested,
    String proName,
    String orderId,
  ) async {
    if (!mounted) return;

    List<Map<String, dynamic>> buttonConfigs = [];
    if (itemCancelRequested) {
      buttonConfigs = [
        {'label': 'ยกเลิก', 'value': 'nothing', 'color': Colors.green},
        {
          'label': 'อนุมัติยกเลิก',
          'value': 'approve_cancel',
          'color': Colors.red,
        },
        {'label': 'รับสินค้า', 'value': 'accept', 'color': Colors.green},
      ];
    } else {
      buttonConfigs = [
        {'label': 'ยกเลิก', 'value': 'nothing', 'color': Colors.green},
        {'label': 'ยืนยัน', 'value': 'confirm', 'color': Colors.blue},
        {'label': 'ยกเลิกสินค้า', 'value': 'cancel_item', 'color': Colors.red},
      ];
    }

    String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(itemCancelRequested ? 'จัดการคำขอ' : 'จัดการรายการ'),
          content: Text(proName),
          actions: buttonConfigs
              .map(
                (config) => TextButton(
                  style: TextButton.styleFrom(foregroundColor: config['color']),
                  onPressed: () => Navigator.of(context).pop(config['value']),
                  child: Text(config['label']),
                ),
              )
              .toList(),
        );
      },
    );

    switch (result) {
      case 'confirm':
      case 'accept':
        await _handleAccept(orderId, rawIndex, proName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ยืนยันรับ "$proName" สำเร็จ')),
          );
        }
        break;
      case 'approve_cancel':
        await _handleApproveCancel(orderId, rawIndex, proName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('อนุมัติยกเลิก "$proName" สำเร็จ')),
          );
        }
        break;
      case 'cancel_item':
        await _handleCancel(orderId, rawIndex, proName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ยกเลิกสินค้า "$proName" สำเร็จ')),
          );
        }
        break;
      case 'nothing':
      default:
        break;
    }
  }

  // ... (คัดลอก _handleAccept, _handleApproveCancel, _handleCancel, _processAccept, _processCancel, _calcTotals จากโค้ดเดิมของคุณมาวางที่นี่ทั้งหมด – ไม่เปลี่ยน)
  Future<void> _handleAccept(
    String orderId,
    int rawIndex,
    String proName,
  ) async {
    print(
      '=== DEBUG ACCEPT PRESSED === Order $orderId, Raw Index $rawIndex, Item: $proName',
    );
    if (rawIndex < 0 || rawIndex >= widget.itemsRaw.length) {
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
    if (rawIndex < 0 || rawIndex >= widget.itemsRaw.length) {
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
    if (rawIndex < 0 || rawIndex >= widget.itemsRaw.length) {
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
