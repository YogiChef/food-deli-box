import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/widgets/button_widget.dart';
import 'package:vendor_box/widgets/input_textfield.dart';

class VendorProductDetail extends StatefulWidget {
  final dynamic productData;
  const VendorProductDetail({super.key, required this.productData});

  @override
  State<VendorProductDetail> createState() => _VendorProductDetailState();
}

class _VendorProductDetailState extends State<VendorProductDetail> {
  final _proNameCtl = TextEditingController();
  final _brandNameCtl = TextEditingController();
  final _qtyNameCtl = TextEditingController();
  final _proPriceCtl = TextEditingController();
  final _proDesCtl = TextEditingController();
  final _categoryCtl = TextEditingController();

  @override
  void initState() {
    _proNameCtl.text = widget.productData['proName'];
    _brandNameCtl.text = widget.productData['brandName'];
    _qtyNameCtl.text = widget.productData['pqty'].toString();
    _proPriceCtl.text = widget.productData['price'].toString();
    _proDesCtl.text = widget.productData['description'];
    _categoryCtl.text = widget.productData['type'];

    super.initState();
  }

  double? productPrice;
  int? quantity;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink.shade800,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20.r,
              backgroundImage: NetworkImage(widget.productData['imageUrl'][0]),
            ),
            const SizedBox(width: 20),
            Text(
              widget.productData['proName'],
              style: styles(fontSize: 13.sp, color: Colors.white),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20.h),
              InputTextfield(
                controller: _proNameCtl,
                textInputType: TextInputType.text,
                prefixIcon: const Icon(Icons.local_mall_outlined),
                hintText: 'Product Name',
                label: const Text('Product Name'),
                onChanged: (value) {},
              ),
              InputTextfield(
                controller: _brandNameCtl,
                textInputType: TextInputType.text,
                prefixIcon: const Icon(Icons.bookmark_border_rounded),
                hintText: 'Brand Name',
                label: const Text('Brand Name'),
                onChanged: (value) {},
              ),
              InputTextfield(
                // initialValue: widget.productData['qty'].toString(),
                controller: _qtyNameCtl,
                textInputType: TextInputType.text,
                prefixIcon: const Icon(
                  Icons.production_quantity_limits_outlined,
                ),
                hintText: 'Quantity',
                label: const Text('Quantity'),
                onChanged: (value) {
                  quantity = int.parse(value);
                },
              ),
              InputTextfield(
                initialValue: widget.productData['price'].toString(),
                textInputType: TextInputType.text,
                prefixIcon: const Icon(Icons.currency_bitcoin),
                hintText: 'Price',
                label: const Text('Price'),
                onChanged: (value) {
                  productPrice = double.parse(value);
                },
              ),
              InputTextfield(
                maxLength: 400,
                controller: _proDesCtl,
                textInputType: TextInputType.text,
                prefixIcon: const Icon(Icons.description_outlined),
                hintText: 'Description',
                label: const Text('Description'),
                onChanged: (value) {},
              ),
              InputTextfield(
                controller: _categoryCtl,
                textInputType: TextInputType.text,
                prefixIcon: const Icon(Icons.category_outlined),
                hintText: 'Category',
                label: const Text('Category'),
                onChanged: (value) {},
              ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        padding: EdgeInsets.all(12.h),
        child: BottonWidget(
          label: 'Update',
          style: styles(color: Colors.white),
          icon: Icons.update_outlined,
          press: () async {
            await firestore
                .collection('products')
                .doc(widget.productData['proId'])
                .update({
                  'proName': _proNameCtl.text,
                  'brandName': _brandNameCtl.text,
                  'pqty': quantity ?? widget.productData['qty'],
                  'price': widget.productData['price'],
                  'description': _proDesCtl.text,
                  'type': _categoryCtl.text,
                })
                .whenComplete(() => Navigator.pop(context));
          },
        ),
      ),
    );
  }
}
