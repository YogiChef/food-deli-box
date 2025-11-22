// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:vendor_box/pages/nav_pages/tab_bar_upload/general_tab.dart';
import 'package:vendor_box/providers/product_provider.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/widgets/button_widget.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    final ProductProvider _productProvider = Provider.of<ProductProvider>(
      context,
    );
    return DefaultTabController(
      length: 2,
      child: Form(
        key: _formKey,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: mainColor,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(
              'Upload Products',
              style: styles(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            bottom: TabBar(
              labelStyle: styles(color: Colors.white, fontSize: 14.sp),
              dividerColor: Colors.transparent,
              unselectedLabelColor: Colors.blueGrey,
              indicatorColor: Colors.white,
              tabAlignment: TabAlignment.fill,
              indicatorWeight: 3,
              tabs: const [Tab(child: Text('General'))],
            ),
          ),
          body: const TabBarView(children: [GeneralTab()]),

          bottomSheet: sizeList.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.all(10),
                  width: width * 0.8,
                  child: BottonWidget(
                    label: 'Save',
                    style: styles(color: Colors.white),
                    icon: Icons.save_as_rounded,

                    press: () async {
                      if (_formKey.currentState!.validate()) {
                        // Form local validate
                        try {
                          await _productProvider.saveProduct(
                            context,
                          ); // Pass context
                        } catch (e) {
                          // Handle error (e.g., incomplete form)
                          Fluttertoast.showToast(
                            msg: e.toString(),
                            backgroundColor: Colors.red,
                          );
                        }
                      }
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
