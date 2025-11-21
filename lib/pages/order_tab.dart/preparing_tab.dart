import 'dart:convert'; // สำหรับ json.encode/decode normalize
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vendor_box/services/sevice.dart';

class Preparing extends StatefulWidget {
  const Preparing({super.key});

  @override
  State<Preparing> createState() => _PreparingState();
}

class _PreparingState extends State<Preparing> {
  late Set<String> expandedOrders;

  @override
  void initState() {
    super.initState();
    expandedOrders = {};
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: auth.currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .limit(50) // Limit for performance
        .snapshots();

    return Scaffold(
      floatingActionButton:
          null, // FIXED: Suppress FAB to avoid hit test error if present in parent/theme
      body: StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('=== DEBUG SNAPSHOT ERROR === ${snapshot.error}'); // Debug
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
                  SizedBox(height: 16.h),
                  Text(
                    'เกิดข้อผิดพลาดในการโหลด Orders: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: styles(fontSize: 16.sp, color: Colors.red),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'กรุณาสร้าง Composite Index ใน Firebase Console',
                    textAlign: TextAlign.center,
                    style: styles(fontSize: 14.sp, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.yellow.shade900),
            );
          }
          if (snapshot.data!.docs.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Icon(Icons.shopping_cart_outlined, size: 100.w),
                ),
                Center(
                  child: Text(
                    'No pending orders yet!',
                    textAlign: TextAlign.center,
                    style: styles(
                      fontSize: 26.sp,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            );
          }
          // Print snapshot once per update (no spam)
          if (snapshot.hasData) {
            print(
              '=== DEBUG PREPARING SNAPSHOT === Loaded ${snapshot.data!.docs.length} pending orders',
            );
          }
          return ListView.builder(
            physics:
                const BouncingScrollPhysics(), // FIXED: Enable scroll to show all orders
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final DocumentSnapshot document = snapshot.data!.docs[index];
              final Map orderData = document.data() as Map? ?? {};
              final List itemsRaw = orderData['items'] ?? [];
              // FIXED: Track original array index for accurate Firestore updates
              final List<Map<String, dynamic>> items = [];
              for (int rawIndex = 0; rawIndex < itemsRaw.length; rawIndex++) {
                try {
                  final rawItem = itemsRaw[rawIndex];
                  final item = Map<String, dynamic>.from(rawItem ?? {});
                  // FIXED: Filter out empty or accepted items (move to "Delivered" by hiding), but show cancelled for restore
                  final bool isAccepted = item['accepted'] ?? false;
                  final bool isCancelled = item['askme'] ?? false;
                  if (item.isNotEmpty && !isAccepted) {
                    // Hide only accepted; show pending + cancelled
                    item['__rawIndex'] =
                        rawIndex; // Temporary key for original index
                    items.add(item);
                  }
                } catch (e) {
                  print(
                    '=== DEBUG SINGLE ITEM CAST ERROR at rawIndex $rawIndex: $e ===',
                  ); // Debug fallback
                }
              }
              // NEW: Skip rendering entire card if no visible items (all accepted/completed)
              if (items.isEmpty) {
                return const SizedBox.shrink();
              }
              final Timestamp timestamp =
                  orderData['timestamp'] as Timestamp? ?? Timestamp.now();
              final double totalPrice =
                  (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
              final String serviceType =
                  orderData['serviceType']?.toString() ?? 'pickup';
              final double shippingCharge =
                  (orderData['shippingCharge'] as num?)?.toDouble() ?? 0.0;
              final double subTotal = serviceType == 'delivery'
                  ? totalPrice - shippingCharge
                  : totalPrice;
              final bool askme = orderData['askme'] ?? false;
              final String orderId = document.id;
              final String buyerId = orderData['buyerId']?.toString() ?? '';
              // FIXED: Count actual pending items (exclude cancelled)
              final int pendingCount = items
                  .where((item) => !(item['askme'] ?? false))
                  .length;
              // Print vendor name once per order (no spam)
              print(
                '=== DEBUG PREPARING VENDOR NAME === Order ${document.id}: fallback="${orderData['bussinessName']?.toString() ?? 'Unknown Vendor'}"',
              );
              // Print shipping debug
              print(
                '=== DEBUG PREPARING SHIPPING === Order ${document.id}: serviceType="$serviceType", shippingCharge=$shippingCharge, subTotal=$subTotal, totalPrice=$totalPrice',
              );
              // Print items debug for index tracking
              print(
                '=== DEBUG ITEMS INDEX === Order $orderId: rawLength=${itemsRaw.length}, filteredItems=${items.length} (hidden accepted), pendingCount=$pendingCount',
              );
              // FIXED: Debug print for buyer details (to check if fields exist in Firestore)
              print(
                '=== DEBUG BUYER DETAILS === Order $orderId: fullName="${orderData['fullName']}", address="${orderData['address']}", custphone="${orderData['custphone']}", custemail="${orderData['custemail']}", buyerImage="${orderData['buyerImage']}", buyerId="$buyerId"',
              );
              // Service badge
              final IconData serviceIcon = serviceType == 'delivery'
                  ? Icons.delivery_dining
                  : Icons.store;
              final Color serviceColor = serviceType == 'delivery'
                  ? Colors.green
                  : Colors.blue;
              final String serviceLabel = serviceType.toUpperCase();
              // Build children: Slidable per item + order summary + buyer details
              List<Widget> expansionChildren = [];
              final bool hasValidItems = items.isNotEmpty;
              if (hasValidItems) {
                // FIXED: Use SingleChildScrollView with Column for better gesture handling in nested Slidable
                expansionChildren.add(
                  SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: items.asMap().entries.map((entry) {
                        final int uiIndex = entry.key;
                        final Map<String, dynamic> item = entry.value;
                        final int rawIndex =
                            item['__rawIndex']
                                as int; // Use original raw index for Firestore
                        final bool itemAskme = item['askme'] ?? false;
                        final bool itemAccepted =
                            item['accepted'] ??
                            false; // Should be false due to filter
                        final String proName =
                            item['proName']?.toString() ?? '';
                        final int quantity =
                            (item['quantity'] as num?)?.toInt() ?? 1;
                        final double price =
                            (item['price'] as num?)?.toDouble() ?? 0.0;
                        final double? extraPrice = (item['extraPrice'] as num?)
                            ?.toDouble();
                        final String productSize =
                            item['productSize']?.toString() ?? '';
                        final List selectedOptionsRaw =
                            item['selectedOptions'] ?? [];
                        final List<Map<String, dynamic>> selectedOptions =
                            selectedOptionsRaw
                                .map(
                                  (opt) => Map<String, dynamic>.from(opt ?? {}),
                                )
                                .toList();
                        final String optionsText = selectedOptions
                            .map(
                              (opt) =>
                                  '${opt['name']?.toString()} (+฿${(opt['price'] as num?)?.toDouble() ?? 0})',
                            )
                            .join(', ');
                        final double itemSubtotal =
                            (price + (extraPrice ?? 0.0)) * quantity;
                        final String itemId =
                            item['proId']?.toString() ??
                            'unknown'; // For item key
                        final List? imagesRaw = item['imageUrl'] as List?;
                        final String productImage =
                            (imagesRaw != null && imagesRaw.isNotEmpty)
                            ? imagesRaw.first.toString()
                            : ''; // FIXED: Debug print for action
                        print(
                          '=== DEBUG ITEM BUILD === Order $orderId, UI Index: $uiIndex, Raw Index: $rawIndex, Item: $proName, Cancelled: $itemAskme',
                        );
                        // FIXED: Conditional actions based on item status
                        final bool isCancelling = !itemAskme;
                        List<Widget> actionChildren = [
                          SlidableAction(
                            flex: 2,
                            onPressed: (_) async {
                              print(
                                '=== DEBUG CANCEL/RESTORE PRESSED === Order $orderId, Raw Index $rawIndex, Item: $proName, itemsRaw length: ${itemsRaw.length}',
                              );
                              if (rawIndex < 0 || rawIndex >= itemsRaw.length) {
                                Fluttertoast.showToast(
                                  msg: 'Invalid item index: $rawIndex',
                                );
                                return;
                              }
                              EasyLoading.show(
                                status: isCancelling
                                    ? 'Cancelling item...'
                                    : 'Restoring item...',
                              );
                              try {
                                final proId = item['proId']?.toString() ?? '';
                                final bool newAskme = !itemAskme;
                                final int iQuantity =
                                    (item['quantity'] as num?)?.toInt() ?? 1;
                                await firestore.runTransaction((tx) async {
                                  final docRef = firestore
                                      .collection('orders')
                                      .doc(orderId);
                                  final snap = await tx.get(docRef);
                                  if (snap.exists) {
                                    final data = snap.data() as Map;
                                    final List itemsList = List.from(
                                      data['items'] ?? [],
                                    );
                                    if (rawIndex >= 0 &&
                                        rawIndex < itemsList.length) {
                                      final Map<String, dynamic> targetItem =
                                          Map<String, dynamic>.from(
                                            itemsList[rawIndex],
                                          );
                                      // Update askme in place
                                      targetItem['askme'] = newAskme;
                                      itemsList[rawIndex] = targetItem;
                                      // Stock adjustment
                                      if (proId.isNotEmpty) {
                                        final prodRef = FirebaseFirestore
                                            .instance
                                            .collection('products')
                                            .doc(proId);
                                        final prodSnap = await tx.get(prodRef);
                                        if (prodSnap.exists) {
                                          int pqty =
                                              (prodSnap.data()?['pqty']
                                                          as num? ??
                                                      0)
                                                  .toInt();
                                          if (newAskme) {
                                            // Cancelling: restore stock
                                            pqty += iQuantity;
                                          } else {
                                            // Restoring: subtract stock
                                            if (pqty >= iQuantity) {
                                              pqty -= iQuantity;
                                            } else {
                                              throw Exception(
                                                'Insufficient stock to restore',
                                              );
                                            }
                                          }
                                          tx.update(prodRef, {'pqty': pqty});
                                        }
                                      }
                                      // Recalculate totals excluding cancelled items (for pending view)
                                      double newPendingSubTotal = 0.0;
                                      for (var it in itemsList) {
                                        if (!(it['askme'] ?? false) &&
                                            !(it['accepted'] ?? false)) {
                                          final double itPrice =
                                              (it['price'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                          final double? itExtra =
                                              (it['extraPrice'] as num?)
                                                  ?.toDouble();
                                          final int itQty =
                                              (it['quantity'] as num?)
                                                  ?.toInt() ??
                                              1;
                                          newPendingSubTotal +=
                                              (itPrice + (itExtra ?? 0.0)) *
                                              itQty;
                                        }
                                      }
                                      final String itServiceType =
                                          data['serviceType']?.toString() ??
                                          'pickup';
                                      final double itShippingCharge =
                                          (data['shippingCharge'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      final double newTotalPrice =
                                          itServiceType == 'delivery'
                                          ? newPendingSubTotal +
                                                itShippingCharge
                                          : newPendingSubTotal;
                                      // Update order
                                      tx.update(docRef, {
                                        'items': itemsList,
                                        'totalPrice':
                                            newTotalPrice, // Update to pending total
                                      });
                                    } else {
                                      throw Exception(
                                        'Invalid index $rawIndex',
                                      );
                                    }
                                  }
                                });
                                EasyLoading.dismiss();
                                Fluttertoast.showToast(
                                  msg: isCancelling
                                      ? 'Item cancelled'
                                      : 'Item restored',
                                );
                              } catch (e) {
                                EasyLoading.dismiss();
                                Fluttertoast.showToast(
                                  msg:
                                      '${isCancelling ? 'Cancel' : 'Restore'} failed: $e',
                                  backgroundColor: Colors.red,
                                );
                              }
                            },
                            backgroundColor: itemAskme
                                ? Colors.green
                                : const Color(0xFFFE4A49),
                            foregroundColor: Colors.white,
                            icon: itemAskme ? Icons.restore : Icons.cancel,
                            label: itemAskme ? 'Restore Item' : 'Cancel Item',
                          ),
                        ];
                        // Add Accept action only if not accepted (always true due to filter, but conditional for safety)
                        if (!itemAccepted) {
                          actionChildren.add(
                            SlidableAction(
                              flex: 2,
                              onPressed: (_) async {
                                print(
                                  '=== DEBUG ACCEPT PRESSED === Order $orderId, Raw Index $rawIndex, Item: $proName, itemsRaw length: ${itemsRaw.length}',
                                );
                                // FIXED: Validation for index
                                if (rawIndex < 0 ||
                                    rawIndex >= itemsRaw.length) {
                                  Fluttertoast.showToast(
                                    msg: 'Invalid item index: $rawIndex',
                                  );
                                  return;
                                }
                                bool orderDelivered = false;
                                // FIXED: Use transaction to mark item as accepted (no remove, just mark & recalculate pending)
                                try {
                                  await firestore.runTransaction((tx) async {
                                    final docRef = firestore
                                        .collection('orders')
                                        .doc(orderId);
                                    final snap = await tx.get(docRef);
                                    if (snap.exists) {
                                      final data = snap.data() as Map;
                                      final List itemsList = List.from(
                                        data['items'] ?? [],
                                      );
                                      final String itServiceType =
                                          data['serviceType']?.toString() ??
                                          'pickup';
                                      final double itShippingCharge =
                                          (data['shippingCharge'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      if (rawIndex >= 0 &&
                                          rawIndex < itemsList.length) {
                                        final Map<String, dynamic> targetItem =
                                            Map<String, dynamic>.from(
                                              itemsList[rawIndex],
                                            );
                                        // Mark as accepted (keep in array for Delivered to show)
                                        targetItem['accepted'] = true;
                                        itemsList[rawIndex] = targetItem;

                                        // Stock adjustment for cancelled items (if was cancelled before accept)
                                        final proId =
                                            targetItem['proId']?.toString() ??
                                            '';
                                        final iQty =
                                            (targetItem['quantity'] as num?)
                                                ?.toInt() ??
                                            1;
                                        final bool wasCancelled =
                                            targetItem['askme'] ?? false;
                                        if (proId.isNotEmpty && wasCancelled) {
                                          final prodRef = FirebaseFirestore
                                              .instance
                                              .collection('products')
                                              .doc(proId);
                                          final prodSnap = await tx.get(
                                            prodRef,
                                          );
                                          if (prodSnap.exists) {
                                            final pqty =
                                                (prodSnap.data()?['pqty']
                                                            as num? ??
                                                        0)
                                                    .toInt();
                                            if (pqty >= iQty) {
                                              tx.update(prodRef, {
                                                'pqty': pqty - iQty,
                                              });
                                            } else {
                                              throw Exception(
                                                'Insufficient stock to accept cancelled item',
                                              );
                                            }
                                          }
                                        }
                                        // Recalculate pending totals (exclude accepted & cancelled)
                                        double newPendingSubTotal = 0.0;
                                        bool allAccepted = true;
                                        for (var it in itemsList) {
                                          final bool itAccepted =
                                              it['accepted'] ?? false;
                                          final bool itCancelled =
                                              it['askme'] ?? false;
                                          if (!itAccepted && !itCancelled) {
                                            final double itPrice =
                                                (it['price'] as num?)
                                                    ?.toDouble() ??
                                                0.0;
                                            final double? itExtra =
                                                (it['extraPrice'] as num?)
                                                    ?.toDouble();
                                            final int itQty =
                                                (it['quantity'] as num?)
                                                    ?.toInt() ??
                                                1;
                                            newPendingSubTotal +=
                                                (itPrice + (itExtra ?? 0.0)) *
                                                itQty;
                                          }
                                          if (!itAccepted) allAccepted = false;
                                        }
                                        final double newTotalPrice =
                                            itServiceType == 'delivery'
                                            ? newPendingSubTotal +
                                                  itShippingCharge
                                            : newPendingSubTotal;
                                        // FIXED: Set deliveredAt to current time every time an item is accepted (latest approve time)
                                        final Timestamp approveTime =
                                            Timestamp.now();
                                        // NEW: Auto-move to delivered if all items accepted
                                        if (allAccepted) {
                                          orderDelivered = true;
                                          tx.update(docRef, {
                                            'items': itemsList,
                                            'status':
                                                'delivered', // Change to 'delivered' for Delivered page
                                            'totalPrice':
                                                newTotalPrice, // Keep as 0 or original? Use original total for completed
                                            'deliveredAt':
                                                approveTime, // FIXED: Set delivered time for full delivery
                                          });
                                        } else {
                                          tx.update(docRef, {
                                            'items': itemsList,
                                            'totalPrice':
                                                newTotalPrice, // Pending total
                                            'deliveredAt':
                                                approveTime, // FIXED: Set delivered time for partial (latest approve)
                                          });
                                        }
                                        print(
                                          '=== DEBUG APPROVE TIME SET === Order $orderId: deliveredAt = $approveTime',
                                        );
                                      } else {
                                        throw Exception(
                                          'Invalid index $rawIndex',
                                        );
                                      }
                                    }
                                  });
                                  // FIXED: Conditional toast based on whether it was the last item
                                  final String msg = orderDelivered
                                      ? 'Order delivered! All items accepted.'
                                      : 'Item accepted and ready for delivery';
                                  Fluttertoast.showToast(msg: msg);
                                  // FIXED: Close expansion tile if order completed (forces UI refresh via setState + stream)
                                  if (orderDelivered) {
                                    setState(() {
                                      expandedOrders.remove(orderId);
                                    });
                                  }
                                } catch (e) {
                                  Fluttertoast.showToast(
                                    msg: 'Accept failed: $e',
                                    backgroundColor: Colors.red,
                                  );
                                }
                              },
                              backgroundColor: const Color(0xFF21B7CA),
                              foregroundColor: Colors.white,
                              icon: Icons.check_circle,
                              label: 'Accept Item',
                            ),
                          );
                        }
                        return Container(
                          key: ValueKey('$orderId-$itemId-$rawIndex'),
                          margin: EdgeInsets.only(bottom: 8.h),
                          child: Slidable(
                            closeOnScroll: true,
                            direction: Axis.horizontal,
                            enabled: true,
                            startActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              children: actionChildren,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {},
                                child: Padding(
                                  padding: EdgeInsets.all(16.w),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // FIXED: Product image for item (not store)
                                          SizedBox(
                                            height: 50.h,
                                            width: 50.w,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                              child: productImage.isNotEmpty
                                                  ? Image.network(
                                                      productImage,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            size: 50.w,
                                                          ),
                                                    )
                                                  : Icon(
                                                      Icons.image_not_supported,
                                                      size: 50.w,
                                                    ),
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                    style: styles(
                                                      fontSize: 12.sp,
                                                      color: Colors.black45,
                                                    ),
                                                  ),
                                                ],
                                                if (optionsText.isNotEmpty) ...[
                                                  SizedBox(height: 2.h),
                                                  Text(
                                                    optionsText,
                                                    style: styles(
                                                      fontSize: 11.sp,
                                                      color: Colors.black45,
                                                    ),
                                                  ),
                                                ],
                                                SizedBox(height: 4.h),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '฿${price.toStringAsFixed(2)} x $quantity',
                                                      style: styles(
                                                        fontSize: 12.sp,
                                                        color: Colors.black45,
                                                      ),
                                                    ),
                                                    Spacer(),
                                                    Text(
                                                      '= ฿${itemSubtotal.toStringAsFixed(2)}',
                                                      style: styles(
                                                        fontSize: 13.sp,
                                                        color:
                                                            Colors.deepOrange,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (extraPrice != null &&
                                                    extraPrice > 0) ...[
                                                  Text(
                                                    'Extra: +฿${extraPrice.toStringAsFixed(2)}',
                                                    style: styles(
                                                      fontSize: 12.sp,
                                                      color: Colors.orange,
                                                    ),
                                                  ),
                                                ],
                                                // FIXED: Add status indicator per item (only for cancelled, since accepted hidden)
                                                if (itemAskme) ...[
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                      top: 4.h,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.cancel,
                                                          size: 16.sp,
                                                          color: Colors.red,
                                                        ),
                                                        SizedBox(width: 4.w),
                                                        Text(
                                                          'Cancelled',
                                                          style: styles(
                                                            fontSize: 12.sp,
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ],
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
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              } else {
                expansionChildren.add(
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      'ไม่มีรายการสินค้า (ทั้งหมดย้ายไป Delivered แล้ว)',
                      style: styles(fontSize: 14.sp, color: Colors.grey),
                    ),
                  ),
                );
              }
              // Add order summary with subtotal and shipping (for pending)
              expansionChildren.add(
                Container(
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
                            style: styles(
                              fontSize: 14.sp,
                              color: Colors.black54,
                            ),
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
                              style: styles(
                                fontSize: 14.sp,
                                color: Colors.black54,
                              ),
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
                      Divider(height: 20.h, color: Colors.transparent),
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
                ),
              );
              // FIXED: Enhanced buyer details - Fallback to default avatar if buyerImage empty
              final String orderEmail =
                  orderData['custemail']?.toString() ?? '';
              final String orderBuyerImage =
                  orderData['buyerImage']?.toString() ?? ''; // From order
              final String orderPhone =
                  orderData['custphone']?.toString() ?? '';
              final String orderAddress =
                  orderData['address']?.toString() ?? '';
              final String orderFullName =
                  orderData['fullName']?.toString() ?? 'Unknown Buyer';

              // Default avatar URL (ใช้ Gravatar หรือ placeholder)
              final String defaultAvatarUrl =
                  'https://ui-avatars.com/api/?name=${Uri.encodeComponent(orderFullName)}&background=ff6b35&color=fff&size=128'; // Dynamic default based on name

              // Log order fields for quick check
              print(
                '=== DEBUG ORDER FIELDS === Order $orderId: email="$orderEmail", buyerImage="$orderBuyerImage" (default: $defaultAvatarUrl)',
              );

              Widget
              buyerSection = FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: buyerId.isNotEmpty
                    ? FirebaseFirestore.instance
                          .collection('buyers')
                          .doc(buyerId)
                          .get()
                    : null,
                builder: (context, buyerSnapshot) {
                  String email = orderEmail.isNotEmpty ? orderEmail : 'N/A';
                  String buyerImageUrl =
                      orderBuyerImage.isNotEmpty && orderBuyerImage != 'null'
                      ? orderBuyerImage
                      : defaultAvatarUrl; // FIXED: Fallback to dynamic default

                  if (buyerSnapshot.connectionState == ConnectionState.done) {
                    if (buyerSnapshot.hasError) {
                      print(
                        '=== DEBUG BUYER FETCH ERROR === Order $orderId: ${buyerSnapshot.error}',
                      );
                    } else if (buyerSnapshot.hasData &&
                        buyerSnapshot.data!.exists) {
                      final buyerData =
                          buyerSnapshot.data!.data() ?? <String, dynamic>{};
                      final String? buyerEmail = buyerData['email']?.toString();
                      email = buyerEmail ?? email;
                      final String? buyerDocImage = buyerData['image']
                          ?.toString(); // Or 'profileImage'
                      if (buyerDocImage != null &&
                          buyerDocImage.isNotEmpty &&
                          buyerDocImage != 'null') {
                        buyerImageUrl = buyerDocImage; // Prefer doc if valid
                      } else if (orderBuyerImage.isEmpty) {
                        buyerImageUrl =
                            defaultAvatarUrl; // Use default if both empty
                      }
                      print(
                        '=== DEBUG BUYER FETCH SUCCESS === Order $orderId: email="$email", buyerImage="$buyerImageUrl" (from doc: "$buyerDocImage")',
                      );
                    } else {
                      print(
                        '=== DEBUG BUYER NOT FOUND === Order $orderId - Using order/default: email="$orderEmail", buyerImage="$buyerImageUrl"',
                      );
                      if (orderBuyerImage.isEmpty) {
                        buyerImageUrl = defaultAvatarUrl;
                      }
                    }
                  } else if (orderBuyerImage.isEmpty) {
                    buyerImageUrl =
                        defaultAvatarUrl; // While loading, use default
                  }

                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      border: Border(
                        top: BorderSide(color: Colors.orange.shade200),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buyer Details',
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
                            CircleAvatar(
                              radius: 20.r,
                              backgroundImage: buyerImageUrl.isNotEmpty
                                  ? NetworkImage(buyerImageUrl)
                                  : null,
                              backgroundColor: Colors.grey.shade200,
                              child: buyerImageUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 20.r,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
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
                                            'Tel: $orderPhone',
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
              expansionChildren.add(buyerSection);
              final bool isExpanded = expandedOrders.contains(orderId);
              return Slidable(
                key: ValueKey(
                  document.id,
                ), // FIXED: เพิ่ม key เพื่อป้องกัน rebuild ไม่จำเป็น
                enabled:
                    !isExpanded, // FIXED: Disable outer Slidable when expanded to avoid gesture conflict with inner
                startActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      flex: 3,
                      onPressed: (context) async {
                        final String orderId = document.id;
                        final bool newAskme = !askme;
                        await firestore
                            .collection('orders')
                            .doc(orderId)
                            .update({'askme': newAskme});
                        if (!newAskme) {
                          await firestore
                              .collection('orders')
                              .doc(orderId)
                              .update({'status': 'cancelled'});
                        }
                      },
                      backgroundColor: askme
                          ? Colors.green
                          : const Color(0xFFFE4A49),
                      foregroundColor: Colors.grey.shade100,
                      icon: askme ? Icons.restore : Icons.auto_delete,
                      label: askme ? 'Please Wait..' : 'Cancel Order',
                    ),
                  ],
                ),
                child: Card(
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  color: askme ? Colors.red.withAlpha(10) : Colors.white,
                  child: ExpansionTile(
                    backgroundColor: Colors.grey.shade100,
                    collapsedIconColor: Colors.transparent,
                    iconColor: Colors.transparent,
                    tilePadding: EdgeInsets.only(left: 8.w, right: 8.w),
                    collapsedBackgroundColor: askme
                        ? Colors.red.withAlpha(30)
                        : Colors.white,
                    initiallyExpanded: isExpanded, // FIXED: Sync with state
                    onExpansionChanged: (expanded) {
                      setState(() {
                        if (expanded) {
                          expandedOrders.add(orderId);
                        } else {
                          expandedOrders.remove(orderId);
                        }
                      });
                      // FIXED: Close any open inner Slidable when collapsing
                      Slidable.of(context)?.close();
                    },
                    title: Column(
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        serviceIcon,
                                        size: 34.w,
                                        color: serviceColor,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        serviceLabel,
                                        style: styles(
                                          fontSize: 12.sp,
                                          color: serviceColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$pendingCount รายการ',
                                    style: styles(
                                      fontSize: 12.sp,
                                      color: askme
                                          ? Colors.red
                                          : Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    '฿${totalPrice.toStringAsFixed(2)}',
                                    style: styles(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: askme
                                          ? Colors.red
                                          : Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    DateFormat(
                                      'dd/MM/yy - kk:mm',
                                    ).format(timestamp.toDate()),
                                    style: styles(
                                      fontSize: 10.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                      ],
                    ),
                    childrenPadding: EdgeInsets.zero,
                    children: expansionChildren,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
