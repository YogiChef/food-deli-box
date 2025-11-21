// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';
import 'package:vendor_box/pages/main_vendor_page.dart';
import 'package:vendor_box/services/sevice.dart';

// Enum สำหรับประเภทกลุ่มตัวเลือก
enum OptionGroupType {
  free, // ไม่เพิ่มราคา (multi-select)
  singleSelect, // เลือกได้อย่างใดอย่างหนึ่ง (radio, e.g., ขนาดต่าง ๆ)
  multiSelect, // เลือกได้หลายตัว (checkbox, คิดเงินเพิ่ม)
  size, // ขนาดต่าง ๆ ราคาต่างกัน (single select with varying prices)
}

class ProductProvider with ChangeNotifier {
  Map<String, dynamic> productData = {};

  // โครงสร้างกลุ่มตัวเลือก: List of groups, each group has type, name (optional), and list of options
  List<Map<String, dynamic>> optionGroups =
      []; // e.g., [{'type': 'free', 'name': 'Free Toppings', 'options': [{'name': 'Onion', 'price': 0}]}]
  String notes = ''; // field สำหรับคอมเม้นท์

  getFormData({
    String? productName,
    double? productPrice,
    int? qty,
    String? type,
    String? image,
    String? namecate,
    String? description,
    DateTime? date,
    List<String>? imageUrlList,
    bool? chargeShipping,
    double? shippingCharge,
    // String? brandName,
    List<String>? sizeList, // Deprecated, use optionGroups for sizes
    List<Map<String, dynamic>>? optionGroupsData,
    String? notes,
  }) {
    if (productName != null) productData['productName'] = productName;
    if (productPrice != null) productData['productPrice'] = productPrice;
    if (qty != null) productData['qty'] = qty;
    if (type != null) productData['type'] = type;
    if (description != null) productData['description'] = description;
    if (date != null) productData['date'] = date;
    if (imageUrlList != null)
      productData['imageUrlList'] = List.from(imageUrlList); // Deep copy
    if (chargeShipping != null) productData['chargeShipping'] = chargeShipping;
    if (shippingCharge != null) productData['shippingCharge'] = shippingCharge;
    // if (brandName != null) productData['brandName'] = brandName;
    // Ignore sizeList, use optionGroups instead
    if (optionGroupsData != null) {
      optionGroups = List.from(
        optionGroupsData.map((group) => Map<String, dynamic>.from(group)),
      ); // Deep copy groups
      productData['optionGroups'] = optionGroups; // Sync to productData
    }
    if (notes != null) {
      this.notes = notes;
      productData['notes'] = notes;
    }

    notifyListeners();
  }

  // Method เพื่อเพิ่มกลุ่มตัวเลือกใหม่
  void addOptionGroup(OptionGroupType groupType, {String? groupName}) {
    final group = {
      'type': groupType.toString().split('.').last,
      'name': groupName,
      'options': <Map<String, dynamic>>[], // Start empty
    };
    optionGroups.add(group);
    getFormData(optionGroupsData: optionGroups); // Update productData
    notifyListeners();
  }

  // Method เพื่อลบกลุ่มตัวเลือก
  void removeOptionGroup(int groupIndex) {
    if (groupIndex >= 0 && groupIndex < optionGroups.length) {
      optionGroups.removeAt(groupIndex);
      getFormData(optionGroupsData: optionGroups); // Update productData
      notifyListeners();
    }
  }

  // Method เพื่อเพิ่ม option ในกลุ่ม
  void addOptionToGroup(int groupIndex, Map<String, dynamic> option) {
    if (groupIndex >= 0 && groupIndex < optionGroups.length) {
      final groupType = optionGroups[groupIndex]['type'] as String;
      final price = (option['price'] as num?)?.toDouble() ?? 0.0;
      if (groupType == 'free' && price != 0) {
        Fluttertoast.showToast(msg: 'Free group must have price 0');
        return;
      }
      optionGroups[groupIndex]['options'].add(
        Map<String, dynamic>.from(option),
      );
      getFormData(optionGroupsData: optionGroups);
      notifyListeners();
    }
  }

  // Method เพื่อลบ option ในกลุ่ม
  void removeOptionFromGroup(int groupIndex, int optionIndex) {
    if (groupIndex >= 0 &&
        groupIndex < optionGroups.length &&
        optionIndex >= 0 &&
        optionIndex < optionGroups[groupIndex]['options'].length) {
      optionGroups[groupIndex]['options'].removeAt(optionIndex);
      getFormData(optionGroupsData: optionGroups);
      notifyListeners();
    }
  }

  // Method เพื่อเพิ่มคอมเม้นท์
  void setNotes(String note) {
    notes = note;
    getFormData(notes: notes);
  }

  clearData() {
    productData.clear(); // Clear map
    optionGroups.clear();
    notes = '';
    notifyListeners();
  }

  // FIXED: Load data from Firestore snapshot (for edit mode)
  Future<void> loadFromSnapshot(DocumentSnapshot snapshot) async {
    if (!snapshot.exists) {
      print('Document not found');
      return;
    }

    try {
      final data = snapshot.data() as Map<String, dynamic>? ?? {}; // Null-safe
      print(
        '=== DEBUG LOAD FROM SNAPSHOT === Data keys: ${data.keys.toList()}',
      ); // Debug keys

      // Null-safe access with fallbacks
      getFormData(
        productName: data['proName']?.toString() ?? '', // Map to form field
        productPrice: (data['price'] as num?)?.toDouble() ?? 0.0,
        qty:
            (data['pqty'] ?? data['qty']) as int? ??
            0, // FIXED: Fallback pqty first
        type: data['type']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        date: (data['date'] as Timestamp?)?.toDate(),
        imageUrlList: List<String>.from(
          data['imageUrl'] ?? [],
        ), // Assume 'imageUrl' is list
        chargeShipping: data['chargeShipping'] as bool? ?? false,
        shippingCharge: (data['shippingCharge'] as num?)?.toDouble() ?? 0.0,
        optionGroupsData: List<Map<String, dynamic>>.from(
          data['optionGroups'] ?? [],
        ),
        notes: data['notes']?.toString() ?? '',
      );

      print(
        '=== DEBUG LOAD SUCCESS === Loaded proName: ${productData['productName']}, qty: ${productData['qty']}',
      );
    } catch (e) {
      print('=== DEBUG LOAD ERROR === $e');
      Fluttertoast.showToast(msg: 'Load product failed: $e');
    }
  }

  bool isFormValid() {
    final data = productData;
    // Debug print (keep for now)
    print('=== DEBUG isFormValid ===');
    print('productName: ${data['productName']}');
    print('productPrice: ${data['productPrice']}');
    print('qty: ${data['qty']}');
    print('type: ${data['type']}');
    print('description: ${data['description']}');
    print('imageUrlList length: ${data['imageUrlList']?.length ?? 0}');
    print('chargeShipping: ${data['chargeShipping']}');
    print('shippingCharge: ${data['shippingCharge']}');
    print('optionGroups length: ${optionGroups.length}');

    // FIXED: Null-safe checks (use ? and ?? everywhere)
    final String? productName = data['productName']?.toString();
    final num? productPrice = data['productPrice'] as num?;
    final num? qty = data['qty'] as num?; // num? for safety
    final String? type = data['type']?.toString();
    final String? description = data['description']?.toString();
    final bool? chargeShipping = data['chargeShipping'] as bool?;
    final num? shippingCharge = data['shippingCharge'] as num?;

    if (productName == null || productName.isEmpty) return false;
    if (productPrice == null || productPrice <= 0) return false;
    if (qty == null || qty <= 0) return false;
    if (type == null || type.isEmpty) return false;
    if (description == null || description.isEmpty) return false;
    if ((chargeShipping ?? false) == true &&
        (shippingCharge == null || shippingCharge <= 0))
      return false;
    print('isFormValid: true');
    return true;
  }

  Future<void> saveProduct(BuildContext context) async {
    if (!isFormValid()) {
      throw Exception('Form data incomplete – Please fill all required fields');
    }
    if (auth.currentUser == null) {
      throw Exception('No user logged in – Please login first');
    }
    EasyLoading.show(status: 'Uploading...');
    try {
      DocumentSnapshot userDoc = await firestore
          .collection('vendors')
          .doc(auth.currentUser!.uid)
          .get();
      final vendorData =
          userDoc.data() as Map<String, dynamic>? ?? {}; // Null-safe
      final proId = const Uuid().v4();
      await firestore.collection('products').doc(proId).set({
        'approved': false,
        'proId': proId,
        'proName': productData['productName'],
        'price': productData['productPrice'],
        'pqty':
            productData['qty'], // FIXED: Use 'pqty' consistent with deli_box (not 'qty')
        'type': productData['type'],
        'description': productData['description'],
        'date': productData['date'] ?? DateTime.now(),
        'chargeShipping': productData['chargeShipping'] ?? false,
        'shippingCharge': productData['shippingCharge'] ?? 0.0,
        // 'brandName':
        //     productData['brandName'] ??
        //     vendorData['bussinessName'], // Fallback จาก vendor
        'size': productData['sizeList'] ?? [], // Deprecated
        'optionGroups':
            productData['optionGroups'] ?? [], // บันทึกกลุ่มตัวเลือก (รวม size)
        'notes': productData['notes'] ?? '', // บันทึกคอมเม้นท์
        'imageUrl': productData['imageUrlList'] ?? [],
        'bussiName': vendorData['bussinessName'] ?? '',
        'storeImage': vendorData['image'] ?? '',
        'vaddress': vendorData['address'] ?? '',
        'country': vendorData['country'] ?? '',
        'city': vendorData['city'] ?? '',
        'state': vendorData['state'] ?? '',
        'vzipcode': vendorData['vzipcode'] ?? '',
        'phone': vendorData['phone'] ?? '',
        'email': vendorData['email'] ?? '',
        'vendorId': auth.currentUser!.uid,
      });
      clearData(); // Reset form
      Navigator.push(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(builder: (context) => const MainVendorPage()),
      );
      EasyLoading.dismiss();
      Fluttertoast.showToast(msg: 'Product uploaded successfully!');
    } catch (e) {
      EasyLoading.dismiss();
      Fluttertoast.showToast(
        msg: 'Upload failed: $e',
        backgroundColor: Colors.red,
      );
    }
  }
}
