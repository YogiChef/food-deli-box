import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/pages/tab_bar_edit/published_tab.dart';
import 'package:vendor_box/pages/tab_bar_edit/unpublished_tab.dart';
import 'package:vendor_box/services/sevice.dart';

class EditPage extends StatefulWidget {
  const EditPage({super.key});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: mainColor,
          automaticallyImplyLeading: false,
          title: Text(
            'Edit Products',
            style: styles(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            labelStyle: styles(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
            unselectedLabelColor: Colors.white54,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(child: Text('Published')),
              Tab(child: Text('Unpublished')),
            ],
          ),
        ),
        body: const TabBarView(children: [PublishedTab(), UnpublishedTab()]),
      ),
    );
  }
}
