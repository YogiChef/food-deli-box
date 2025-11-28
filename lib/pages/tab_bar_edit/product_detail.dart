// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart'; // สำหรับ Uuid.v4() ใน upload images // สำหรับ TypeTab ถ้าต้องการ edit category
import 'package:vendor_box/providers/product_provider.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/widgets/button_widget.dart';
import 'package:vendor_box/widgets/input_textfield.dart';

class VendorProductDetail extends StatefulWidget {
  final DocumentSnapshot
  productData; // Type เป็น DocumentSnapshot เพื่อ safe access
  const VendorProductDetail({super.key, required this.productData});

  @override
  State<VendorProductDetail> createState() => _VendorProductDetailState();
}

class _VendorProductDetailState extends State<VendorProductDetail> {
  final _formKey = GlobalKey<FormState>(); // Form validation
  final _proNameCtl = TextEditingController();
  final _qtyNameCtl = TextEditingController();
  final _proPriceCtl = TextEditingController();
  final _proDesCtl = TextEditingController();
  final _categoryCtl = TextEditingController(); // สำหรับ type/category
  final _shippingChargeCtl = TextEditingController();
  final ImagePicker picker = ImagePicker();
  final List<File> _newImages = []; // สำหรับ add images ใหม่
  List<String> _imageUrlList = []; // Load จาก productData
  bool _chargeShipping = false;
  DateTime? _scheduleDate; // สำหรับ date
  final List<String> _categoryList = []; // Load categories
  int? quantity; // สำหรับ qty parse
  double? productPrice; // สำหรับ price parse

  @override
  void initState() {
    super.initState();
    _loadCategories(); // Load category list
    _loadProductData(); // Load fields
  }

  // Load categories (คล้าย getType() ใน upload)
  Future<void> _loadCategories() async {
    try {
      final snapshot = await firestore.collection('type').get();
      for (var doc in snapshot.docs) {
        _categoryList.add(doc['typename']);
      }
      setState(() {});
    } catch (e) {
      print('Load categories error: $e');
    }
  }

  // Load all fields จาก productData ด้วย safe access
  void _loadProductData() {
    final data =
        widget.productData.data() as Map<String, dynamic>? ?? {}; // Cast safe
    _proNameCtl.text = data['proName']?.toString() ?? '';
    _qtyNameCtl.text = (data['pqty'] ?? 0).toString();
    _proPriceCtl.text = (data['price'] ?? 0).toString();
    _proDesCtl.text = data['description']?.toString() ?? '';
    _categoryCtl.text = data['type']?.toString() ?? '';
    _chargeShipping = data['chargeShipping'] ?? false;
    _shippingChargeCtl.text = (data['shippingCharge'] ?? 0).toString();

    // Convert Timestamp to DateTime
    final dateValue = data['date'];
    if (dateValue is Timestamp) {
      _scheduleDate = dateValue.toDate(); // Convert safe
    } else if (dateValue is DateTime) {
      _scheduleDate = dateValue;
    } else {
      _scheduleDate = null;
    }

    _imageUrlList = List<String>.from(data['imageUrl'] ?? []);

    // ใหม่: Load optionGroups ใน Provider (สำหรับ edit)
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final optionGroups = data['optionGroups'] as List<dynamic>? ?? [];
    provider.loadOptionGroups(
      optionGroups,
    ); // Assume provider มี method loadOptionGroups
  }

  @override
  void dispose() {
    _proNameCtl.dispose();
    _qtyNameCtl.dispose();
    _proPriceCtl.dispose();
    _proDesCtl.dispose();
    _categoryCtl.dispose();
    _shippingChargeCtl.dispose();
    super.dispose();
  }

  // Upload new images และ return URLs
  Future<List<String>> _uploadNewImages() async {
    List<String> newUrls = [];
    for (var img in _newImages) {
      try {
        final ref = storage
            .ref()
            .child('productImage')
            .child(const Uuid().v4().toString());
        final task = ref.putFile(img);
        final snapshot = await task;
        final url = await snapshot.ref.getDownloadURL();
        newUrls.add(url);
      } catch (e) {
        Fluttertoast.showToast(msg: 'Upload image failed: $e');
      }
    }
    return newUrls;
  }

  // Save all fields
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Upload new images ถ้ามี
      final newImageUrls = await _uploadNewImages();
      if (newImageUrls.isNotEmpty) {
        _imageUrlList.addAll(newImageUrls);
      }

      final provider = Provider.of<ProductProvider>(context, listen: false);
      // ใหม่: Save optionGroups จาก Provider
      final optionGroups = provider.optionGroups;

      // Update doc ใน Firestore
      await firestore.collection('products').doc(widget.productData.id).update({
        'proName': _proNameCtl.text.trim(), // Optional
        'pqty': quantity ?? int.tryParse(_qtyNameCtl.text) ?? 0,
        'price': productPrice ?? double.tryParse(_proPriceCtl.text) ?? 0.0,
        'description': _proDesCtl.text.trim(),
        'type': _categoryCtl.text.trim(), // category
        'chargeShipping': _chargeShipping,
        'shippingCharge': _chargeShipping
            ? double.tryParse(_shippingChargeCtl.text) ?? 0.0
            : 0.0,
        'date': _scheduleDate != null
            ? Timestamp.fromDate(_scheduleDate!)
            : null, // Convert to Timestamp
        'imageUrl': _imageUrlList, // Images
        'optionGroups': optionGroups, // Save options
      });

      Fluttertoast.showToast(msg: 'อัปเดตสินค้าสำเร็จ!');
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'อัปเดตผิดพลาด: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20.r,
              backgroundColor: _imageUrlList.isNotEmpty ? null : Colors.grey,
              backgroundImage: _imageUrlList.isNotEmpty
                  ? NetworkImage(_imageUrlList[0])
                  : null,
              child: _imageUrlList.isNotEmpty
                  ? null
                  : const Icon(Icons.image, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.productData.get('proName')?.toString() ??
                    'Unnamed Product',
                style: styles(fontSize: 13.sp, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            children: [
              // Category (Dropdown)
              // Images Preview + Add New
              SizedBox(
                height: 100.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrlList.length + _newImages.length + 1,
                  itemBuilder: (context, index) {
                    if (index < _imageUrlList.length) {
                      return Stack(
                        children: [
                          Image.network(
                            _imageUrlList[index],
                            width: 80.w,
                            height: 80.h,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 80.w,
                                  height: 80.h,
                                  color: Colors.grey,
                                  child: const Icon(Icons.error),
                                ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _imageUrlList.removeAt(index)),
                            ),
                          ),
                        ],
                      );
                    } else if (index <
                        _imageUrlList.length + _newImages.length) {
                      final newIdx = index - _imageUrlList.length;
                      return Stack(
                        children: [
                          Image.file(
                            _newImages[newIdx],
                            width: 80.w,
                            height: 80.h,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _newImages.removeAt(newIdx)),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return IconButton(
                        icon: const Icon(Icons.add_photo_alternate),
                        onPressed: () async {
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (picked != null)
                            setState(() => _newImages.add(File(picked.path)));
                        },
                      );
                    }
                  },
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _categoryCtl.text.isEmpty
                    ? null
                    : _categoryCtl.text,
                isExpanded: true,
                hint: const Text('Select Category/Type'),
                items: _categoryList
                    .map(
                      (cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(
                          cat,
                          style: styles(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _categoryCtl.text = value ?? ''),
                validator: (value) =>
                    value == null ? 'กรุณาเลือกประเภทสินค้า' : null,
              ),
              SizedBox(height: 16.h),
              // Product Name
              InputTextfield(
                controller: _proNameCtl,
                textInputType: TextInputType.text,
                prefixIcon: const Icon(Icons.drive_file_rename_outline),
                hintText: 'Product Name',
                label: const Text('Product Name'),
                validator: (value) =>
                    value!.isEmpty ? 'กรุณากรอกชื่อสินค้า' : null,
              ),

              // Quantity
              InputTextfield(
                controller: _qtyNameCtl,
                textInputType: TextInputType.number,
                prefixIcon: const Icon(
                  Icons.production_quantity_limits_outlined,
                ),
                hintText: 'Quantity',
                label: const Text('Quantity'),
                validator: (value) {
                  final qty = int.tryParse(value ?? '');
                  return qty == null || qty <= 0 ? 'จำนวนต้องมากกว่า 0' : null;
                },
                onChanged: (value) {
                  // Parse safe
                  if (value.isNotEmpty) {
                    quantity = int.tryParse(value);
                  } else {
                    quantity = null;
                  }
                },
              ),
              // Price
              InputTextfield(
                controller: _proPriceCtl,
                textInputType: TextInputType.number,
                prefixIcon: const Icon(Icons.money_sharp),
                hintText: 'Price',
                label: const Text('Price'),
                validator: (value) {
                  final price = double.tryParse(value ?? '');
                  return price == null || price <= 0
                      ? 'ราคาต้องมากกว่า 0'
                      : null;
                },
                onChanged: (value) {
                  // Parse safe
                  if (value.isNotEmpty) {
                    productPrice = double.tryParse(value);
                  } else {
                    productPrice = null;
                  }
                },
              ),
              // Description
              InputTextfield(
                controller: _proDesCtl,
                textInputType: TextInputType.multiline,
                maxLines: 3,
                prefixIcon: const Icon(Icons.description_outlined),
                hintText: 'Description',
                label: const Text('Description'),
                validator: (value) =>
                    value!.isEmpty ? 'กรุณากรอกรายละเอียด' : null,
              ),
              // Shipping Section
              Consumer<ProductProvider>(
                builder: (context, provider, child) {
                  return ExpansionTile(
                    title: const Text('ตัวเลือกเมนู'),
                    subtitle: Text('${provider.optionGroups.length} กลุ่ม'),
                    leading: const Icon(Icons.menu_book),
                    children: [
                      if (provider.optionGroups.isEmpty)
                        ListTile(
                          title: const Text('ไม่มีกลุ่มตัวเลือก'),
                          subtitle: const Text('กด "เพิ่ม" เพื่อสร้าง'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addGroupDialog,
                          ),
                        )
                      else
                        ...provider.optionGroups.asMap().entries.map((entry) {
                          int groupIndex = entry.key;
                          Map<String, dynamic> group = entry.value;
                          final groupType = group['type'] as String;
                          final groupName =
                              group['name'] ?? groupType.toUpperCase();
                          final options =
                              group['options'] as List<Map<String, dynamic>>;
                          return ExpansionTile(
                            key: ValueKey(groupIndex),
                            title: Text(groupName),
                            subtitle: Text(
                              'ประเภท: $groupType • ${options.length} ตัวเลือก',
                            ),
                            leading: Icon(
                              _getGroupIcon(groupType),
                              color: _getGroupColor(groupType),
                            ),
                            children: [
                              if (options.isEmpty)
                                ListTile(
                                  title: const Text('ไม่มีตัวเลือก'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () =>
                                        _addOptionToGroupDialog(groupIndex),
                                  ),
                                )
                              else
                                ...options.asMap().entries.map((optEntry) {
                                  int optIndex = optEntry.key;
                                  Map<String, dynamic> option = optEntry.value;
                                  return ListTile(
                                    title: Text(option['name']),
                                    subtitle: Text('ราคา: ฿${option['price']}'),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        provider.removeOptionFromGroup(
                                          groupIndex,
                                          optIndex,
                                        );
                                      },
                                    ),
                                  );
                                }).toList(),
                              ListTile(
                                title: const Text('เพิ่มตัวเลือกในกลุ่มนี้'),
                                trailing: const Icon(Icons.add),
                                onTap: () =>
                                    _addOptionToGroupDialog(groupIndex),
                              ),
                              ListTile(
                                title: const Text('ลบกลุ่มนี้'),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    provider.removeOptionGroup(groupIndex);
                                    Fluttertoast.showToast(
                                      msg: 'ลบกลุ่มสำเร็จ!',
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ListTile(
                        title: const Text('เพิ่มกลุ่มตัวเลือกใหม่'),
                        trailing: const Icon(Icons.add),
                        onTap: _addGroupDialog,
                      ),
                    ],
                  );
                },
              ),
              CheckboxListTile(
                title: const Text('Charge Shipping'),
                value: _chargeShipping,
                onChanged: (value) =>
                    setState(() => _chargeShipping = value ?? false),
              ),
              if (_chargeShipping)
                InputTextfield(
                  controller: _shippingChargeCtl,
                  textInputType: TextInputType.number,
                  prefixIcon: const Icon(CupertinoIcons.money_dollar_circle),
                  hintText: 'Shipping Charge (max 5)',
                  label: const Text('Shipping Charge'),
                  validator: (value) {
                    final charge = double.tryParse(value ?? '');
                    if (charge == null || charge <= 0)
                      return 'ค่าส่งต้องมากกว่า 0';
                    if (charge > 5) return 'ค่าส่งไม่เกิน 5';
                    return null;
                  },
                ),
              // Schedule Date
              ListTile(
                title: const Text('Schedule Date'),
                subtitle: Text(
                  _scheduleDate != null
                      ? DateFormat('dd/MM/yyyy').format(_scheduleDate!)
                      : 'Not set',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _scheduleDate ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(5000),
                  );
                  if (date != null) setState(() => _scheduleDate = date);
                },
              ),

              // Option Groups (Full implementation จาก GeneralTab)
              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.h),
        child: BottonWidget(
          label: 'Update Product',
          style: styles(color: Colors.white),
          icon: Icons.update,
          press: _saveProduct,
        ),
      ),
    );
  }

  // Dialog เพื่อเพิ่มกลุ่มตัวเลือกใหม่ (copy จาก GeneralTab)
  void _addGroupDialog() {
    final groupNameController = TextEditingController();
    OptionGroupType? selectedType;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('เพิ่มกลุ่มตัวเลือก'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: groupNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อกลุ่ม',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<OptionGroupType>(
                initialValue: selectedType,
                decoration: const InputDecoration(
                  labelText: 'ประเภทกลุ่ม',
                  border: OutlineInputBorder(),
                ),
                items: OptionGroupType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedType = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                if (selectedType != null) {
                  final provider = Provider.of<ProductProvider>(
                    context,
                    listen: false,
                  );
                  provider.addOptionGroup(
                    selectedType!,
                    groupName: groupNameController.text.trim().isEmpty
                        ? null
                        : groupNameController.text.trim(),
                  );
                  Navigator.pop(context);
                  Fluttertoast.showToast(msg: 'เพิ่มกลุ่มสำเร็จ!');
                } else {
                  Fluttertoast.showToast(
                    msg: 'กรุณาเลือกประเภทกลุ่ม',
                    backgroundColor: Colors.red,
                  );
                }
              },
              child: const Text('เพิ่ม'),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog เพื่อเพิ่ม option ในกลุ่มเฉพาะ (copy จาก GeneralTab)
  void _addOptionToGroupDialog(int groupIndex) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final groupType = provider.optionGroups[groupIndex]['type'] as String;
    final isFree = groupType == 'free';
    if (isFree) {
      priceController.text = '0';
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'เพิ่มตัวเลือกในกลุ่ม: ${provider.optionGroups[groupIndex]['name'] ?? provider.optionGroups[groupIndex]['type']}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อตัวเลือก',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: isFree ? TextInputType.none : TextInputType.number,
              readOnly: isFree,
              decoration: InputDecoration(
                labelText: isFree ? 'ฟรี (ราคา 0)' : 'ราคาเพิ่ม',
                border: const OutlineInputBorder(),
                suffixText: isFree ? '฿0' : '฿',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price = isFree
                  ? 0.0
                  : (double.tryParse(priceController.text.trim()) ?? 0.0);
              if (name.isNotEmpty) {
                provider.addOptionToGroup(groupIndex, {
                  'name': name,
                  'price': price,
                });
                Navigator.pop(context);
                Fluttertoast.showToast(msg: 'เพิ่มตัวเลือกสำเร็จ!');
              } else {
                Fluttertoast.showToast(
                  msg: 'กรุณากรอกชื่อตัวเลือก',
                  backgroundColor: Colors.red,
                );
              }
            },
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
  }

  // Icon สำหรับ group type
  IconData _getGroupIcon(String type) {
    switch (type) {
      case 'free':
        return Icons.free_breakfast;
      case 'singleSelect':
        return Icons.radio_button_checked;
      case 'multiSelect':
        return Icons.check_box;
      case 'size':
        return Icons.straighten;
      default:
        return Icons.menu;
    }
  }

  // Color สำหรับ group type
  Color _getGroupColor(String type) {
    switch (type) {
      case 'free':
        return Colors.green;
      case 'singleSelect':
        return Colors.blue;
      case 'multiSelect':
        return Colors.orange;
      case 'size':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
