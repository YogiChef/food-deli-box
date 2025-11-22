// ignore_for_file: sized_box_for_whitespace, sort_child_properties_last, no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/pages/order_tab.dart/delivered_tab.dart';
import 'package:vendor_box/pages/order_tab.dart/preparing_tab.dart';
import 'package:vendor_box/services/sevice.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: mainColor,
          automaticallyImplyLeading: false,
          title: Text(
            'Orders',
            style: styles(
              fontSize: 20.sp,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 6,
            unselectedLabelColor: Colors.white54,
            labelColor: Colors.white,
            labelStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
            tabs: const [
              Tab(child: Text('Preparing')),
              Tab(child: Text('Delivered')),
            ],
          ),
        ),
        body: const TabBarView(children: [Preparing(), Delivered()]),
      ),
    );
  }
}
