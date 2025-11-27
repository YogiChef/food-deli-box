import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:vendor_box/services/sevice.dart';

class Delivered extends StatefulWidget {
  const Delivered({super.key});

  @override
  State<Delivered> createState() => _DeliveredState();
}

class _DeliveredState extends State<Delivered> {
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    // FIXED: Query orders with status 'pending' OR 'delivered' to catch partial accepted items
    final Stream<QuerySnapshot> ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: auth.currentUser!.uid)
        .where('status', whereIn: ['pending', 'delivered'])
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: ordersStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          print('=== DEBUG DELIVERED ERROR === ${snapshot.error}'); // Debug
          return const Text('Something went wrong');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: width * 0.5,
              child: const LinearProgressIndicator(color: Colors.green),
            ),
          );
        }

        if (snapshot.data!.docs.isEmpty) {
          print(
            '=== DEBUG DELIVERED EMPTY === No orders with accepted items found',
          ); // Debug
          return Center(
            child: Text(
              'No delivered orders yet!',
              style: styles(
                fontSize: 20.sp,
                color: Colors.yellow.shade900,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          );
        }

        print(
          '=== DEBUG DELIVERED LOADED === ${snapshot.data!.docs.length} orders (pending/delivered)',
        ); // Debug

        return ListView(
          children: snapshot.data!.docs
              .map((DocumentSnapshot document) {
                final Map<String, dynamic> orderData =
                    document.data() as Map<String, dynamic>? ?? {};
                print(
                  '=== DEBUG ORDER DATA === ${document.id}: status=${orderData['status']}, $orderData',
                ); // Debug: ดู fields จริง

                final Timestamp timestamp =
                    orderData['timestamp'] as Timestamp? ?? Timestamp.now();
                // FIXED: ใช้ deliveredAt ถ้ามี (เวลาที่ approve ใน Preparing) มิฉะนั้น fallback ไป timestamp (order time)
                final Timestamp deliveredTime =
                    orderData['deliveredAt'] as Timestamp? ?? timestamp;
                final String serviceType =
                    orderData['serviceType']?.toString() ?? 'pickup';
                final double shippingCharge =
                    (orderData['shippingCharge'] as num?)?.toDouble() ?? 0.0;
                final String orderStatus =
                    orderData['status']?.toString() ?? 'pending';

                // FIXED: Fallback fields สำหรับ buyer (รองรับ data เก่า/ใหม่)
                final String fullName =
                    orderData['fullName']?.toString() ?? 'Unknown Buyer';
                final String address = orderData['address']?.toString() ?? '';
                final String phone =
                    orderData['custphone']?.toString() ??
                    orderData['phone']?.toString() ??
                    '';
                final String email =
                    orderData['custemail']?.toString() ??
                    orderData['email']?.toString() ??
                    '';
                print(
                  '=== DEBUG PHONE/EMAIL RESOLVED === phone="$phone", email="$email"',
                ); // Debug เพื่อเช็ค fallback

                // Service badge (match Preparing)
                final IconData serviceIcon = serviceType == 'delivery'
                    ? Icons.delivery_dining
                    : Icons.store;
                final Color serviceColor = serviceType == 'delivery'
                    ? Colors.green
                    : Colors.blue;
                final String serviceLabel = serviceType.toUpperCase();

                // FIXED: Filter & sum accepted items for display & totals (from pending or delivered orders)
                final List itemsRaw = orderData['items'] ?? [];
                final List<Map<String, dynamic>> acceptedItems = [];
                double deliveredSubTotal = 0.0;
                bool isFullyDelivered = (orderStatus == 'delivered');
                for (var rawItem in itemsRaw) {
                  final Map<String, dynamic> item = Map<String, dynamic>.from(
                    rawItem ?? {},
                  );
                  final bool isAccepted = item['accepted'] ?? false;
                  if (isAccepted) {
                    acceptedItems.add(item);
                    final double price =
                        (item['price'] as num?)?.toDouble() ?? 0.0;
                    final double? extraPrice = (item['extraPrice'] as num?)
                        ?.toDouble();
                    final int quantity =
                        (item['quantity'] as num?)?.toInt() ?? 1;
                    deliveredSubTotal +=
                        (price + (extraPrice ?? 0.0)) * quantity;
                  }
                }
                final double deliveredTotal = serviceType == 'delivery'
                    ? deliveredSubTotal + shippingCharge
                    : deliveredSubTotal;
                final bool hasAcceptedItems = acceptedItems.isNotEmpty;

                // Skip if no accepted items (only show orders with at least one accepted)
                if (!hasAcceptedItems) {
                  return const SizedBox.shrink();
                }

                return Card(
                  margin: EdgeInsets.only(left: 10.w, right: 10.w, bottom: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Header: Order Summary (partial or full)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          // color: isFullyDelivered
                          //     ? Colors.green.withAlpha(10)
                          //     : Colors.orange.withAlpha(10),
                          // border: Border(
                          //   bottom: BorderSide(
                          //     color: isFullyDelivered
                          //         ? Colors.green.shade200
                          //         : Colors.orange.shade200,
                          //   ),
                          // ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      serviceIcon,
                                      size: 32.w,
                                      color: serviceColor,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      serviceLabel,
                                      style: styles(
                                        fontSize: 13.sp,
                                        color: serviceColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.only(
                                    bottom: 4.h,
                                    left: 12.w,
                                    right: 12.w,
                                  ),
                                  alignment: Alignment.topCenter,
                                  decoration: BoxDecoration(
                                    color: isFullyDelivered
                                        ? Colors.green
                                        : Colors.orange,
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Text(
                                    isFullyDelivered ? 'ครบแล้ว' : 'ยังไม่ครบ',
                                    style: styles(
                                      fontSize: 13.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd/MM/yy - kk:mm').format(
                                    timestamp.toDate(),
                                  ), // FIXED: ใช้ deliveredTime
                                  style: styles(
                                    fontSize: 11.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${acceptedItems.length}/${itemsRaw.length} รายการ',
                                  style: styles(
                                    fontSize: 12.sp,
                                    color: isFullyDelivered
                                        ? Colors.green
                                        : Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ExpansionTile(
                        collapsedIconColor: Colors.transparent,
                        shape: const RoundedRectangleBorder(),
                        tilePadding: EdgeInsets.only(left: 12.w, right: 12.w),
                        trailing: Padding(
                          padding: EdgeInsets.only(top: 6.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '฿ ${deliveredTotal.toStringAsFixed(2)}',
                                style: styles(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    DateFormat('dd/MM/yy - kk:mm:ss').format(
                                      deliveredTime.toDate(),
                                    ), // FIXED: ใช้ deliveredTime
                                    style: styles(
                                      fontSize: 11.sp,
                                      color: Colors.yellow.shade900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                          fullName,
                          style: styles(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: 12.h,
                              left: 12.w,
                              right: 12.w,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                // FIXED: Transaction Items List (แสดงรายการที่ accepted - accumulative)
                                Text(
                                  'รายการสินค้าที่ส่งแล้ว',
                                  style: styles(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                ...acceptedItems.map<Widget>((item) {
                                  final String proName =
                                      item['proName']?.toString() ?? '';
                                  final String productSize =
                                      item['productSize']?.toString() ?? '';
                                  final int quantity =
                                      (item['quantity'] as num?)?.toInt() ?? 1;
                                  final double price =
                                      (item['price'] as num?)?.toDouble() ??
                                      0.0;
                                  final double? optionPrice =
                                      (item['extraPrice'] as num?)?.toDouble();
                                  final double? extraPrice =
                                      ((item['extraPrice'] as num?)
                                              ?.toDouble() ??
                                          00) *
                                      quantity;
                                  final List? imagesRaw =
                                      item['imageUrl'] as List?;
                                  final String productImage =
                                      (imagesRaw != null &&
                                          imagesRaw.isNotEmpty)
                                      ? imagesRaw.first.toString()
                                      : '';
                                  final double itemSubtotal = price * quantity;
                                  final List selectedOptionsRaw =
                                      item['selectedOptions'] ?? [];
                                  final String optionsText = selectedOptionsRaw
                                      .map(
                                        (opt) =>
                                            '${(opt['name'] ?? '')} (+฿${(opt['price'] as num?)?.toDouble() ?? 0})',
                                      )
                                      .join(', ');

                                  return Container(
                                    // margin: EdgeInsets.only(bottom: 12.h),
                                    padding: EdgeInsets.all(12.w),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      // borderRadius: BorderRadius.circular(8.r),
                                      // border: Border.all(
                                      //   color: Colors.grey.shade300,
                                      // ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Item Image
                                            SizedBox(
                                              height: 60.h,
                                              width: 60.w,
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
                                                              size: 60.w,
                                                            ),
                                                      )
                                                    : Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        size: 60.w,
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
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  if (productSize
                                                      .isNotEmpty) ...[
                                                    SizedBox(height: 2.h),
                                                    Text(
                                                      'Size: $productSize',
                                                      style: styles(
                                                        fontSize: 12.sp,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  ],
                                                  if (optionsText
                                                      .isNotEmpty) ...[
                                                    SizedBox(height: 2.h),
                                                    Text(
                                                      optionsText,
                                                      style: styles(
                                                        fontSize: 11.sp,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  ],
                                                  SizedBox(height: 4.h),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        '฿${price.toStringAsFixed(2)} x $quantity',
                                                        style: styles(
                                                          fontSize: 12.sp,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
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
                                                    Row(
                                                      children: [
                                                        Text(
                                                          'Extra: ฿$optionPrice x $quantity',
                                                          style: styles(
                                                            fontSize: 12.sp,
                                                            color:
                                                                Colors.orange,
                                                          ),
                                                        ),
                                                        Spacer(),
                                                        Text(
                                                          '= ฿${extraPrice.toStringAsFixed(2)}',
                                                          style: styles(
                                                            fontSize: 12.sp,
                                                            color:
                                                                Colors.orange,
                                                          ),
                                                        ),
                                                      ],
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
                                }).toList(),
                                // Footer: Summary (accumulative for accepted items)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withAlpha(10),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'ยอดรวมสินค้า',
                                            style: styles(
                                              fontSize: 14.sp,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            '฿${deliveredSubTotal.toStringAsFixed(2)}',
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
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
                                      Divider(
                                        height: 20.h,
                                        color: Colors.transparent,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
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
                                            '฿${deliveredTotal.toStringAsFixed(2)}',
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
                                SizedBox(height: 12.h),
                                // Buyer Details (ท้ายเรื่อง)
                                Text(
                                  'ข้อมูลผู้สั่งซื้อ',
                                  style: styles(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        right: 12.w,
                                        top: 8.w,
                                      ),
                                      child: CircleAvatar(
                                        radius: 20.r,
                                        backgroundImage:
                                            orderData['buyerImage']
                                                    ?.toString() !=
                                                null
                                            ? NetworkImage(
                                                orderData['buyerImage']
                                                    .toString(),
                                              )
                                            : null,
                                        child: orderData['buyerImage'] == null
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.only(top: 4.w),
                                            child: Text(
                                              fullName,
                                              style: styles(
                                                fontSize: 12.sp,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            address,
                                            maxLines: 3,
                                            style: styles(
                                              fontSize: 12.sp,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          if (phone.isNotEmpty) ...[
                                            Text(
                                              phone,
                                              style: styles(
                                                fontSize: 12.sp,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                          if (email.isNotEmpty) ...[
                                            Text(
                                              email,
                                              style: styles(
                                                fontSize: 12.sp,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                          // Fallback สำหรับ fields เก่า
                                          if (orderData['city'] != null ||
                                              orderData['state'] != null) ...[
                                            Text(
                                              '${orderData['city']?.toString() ?? ''}, ${orderData['state']?.toString() ?? ''}',
                                              style: styles(
                                                fontSize: 12.sp,
                                                color: Colors.black54,
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
                        ],
                      ),
                      SizedBox(height: 8.h),
                    ],
                  ),
                );
              })
              .where((widget) => widget != const SizedBox.shrink())
              .toList(), // Filter out skipped orders
        );
      },
    );
  }
}
