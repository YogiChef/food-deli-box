// ignore_for_file: no_leading_underscores_for_local_identifiers, use_rethrow_when_possible

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor_box/services/sevice.dart';

class VendorController {
  // Future<String> saveVendor(
  //   String name,
  //   String email,
  //   String phone,
  //   String addres,
  //   String zipcode,
  //   String countryValue,
  //   String stateValue,
  //   String cityValue,
  //   String taxStatus,
  //   String taxNumber,
  //   Uint8List? image,
  //   String category,
  // ) async {
  //   String res = 'some error occured';
  //   try {
  //     String storeImage = await uploadImagToStorage(image!);

  //     await firestore.collection('vendors').doc(auth.currentUser!.uid).set({
  //       'vendorId': auth.currentUser!.uid,
  //       'category': category,
  //       'bussinessName': name,
  //       'email': email,
  //       'phone': phone,
  //       'address': addres,
  //       'vzipcode': zipcode,
  //       'country': countryValue,
  //       'state': stateValue,
  //       'city': cityValue,
  //       'taxStatus': taxStatus,
  //       'taxNo': taxNumber,
  //       'image': storeImage,
  //       'approved': false,
  //     });
  //   } catch (e) {
  //     Fluttertoast.showToast(msg: e.toString());
  //   }
  //   return res;
  // }

  // loginUser(String email, String password) async {
  //   try {
  //     if (email.isNotEmpty && password.isNotEmpty) {
  //       await auth.signInWithEmailAndPassword(email: email, password: password);

  //       Fluttertoast.showToast(msg: 'you are login success');
  //     } else {
  //       Fluttertoast.showToast(msg: 'Please Fields must not be empty');
  //     }
  //   } catch (e) {
  //     Fluttertoast.showToast(msg: e.toString());
  //   }
  // }

  // pickStoreImage(ImageSource source) async {
  //   final ImagePicker _imgPicker = ImagePicker();
  //   XFile? _file = await _imgPicker.pickImage(source: source);

  //   if (_file != null) {
  //     return await _file.readAsBytes();
  //   } else {
  //     Fluttertoast.showToast(msg: 'No image seleted');
  //   }
  // }

  loginUser(String email, String password) async {
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        await auth.signInWithEmailAndPassword(email: email, password: password);
        Fluttertoast.showToast(msg: 'เข้าสู่ระบบสำเร็จ');
      } else {
        Fluttertoast.showToast(msg: 'กรุณากรอกข้อมูลให้ครบ');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }
  }

  pickStoreImage(ImageSource source) async {
    final ImagePicker _imgPicker = ImagePicker();
    XFile? _file = await _imgPicker.pickImage(source: source);

    if (_file != null) {
      return await _file.readAsBytes();
    } else {
      Fluttertoast.showToast(msg: 'ไม่เลือกรูปภาพ');
      throw Exception('No image selected');
    }
  }

  // เพิ่มถ้าขาด (สำหรับ upload image ใน register)
  Future<String> uploadImagToStorage(Uint8List imageBytes) async {
    try {
      Reference ref = storage
          .ref()
          .child('vendorImages')
          .child(auth.currentUser!.uid);
      UploadTask uploadTask = ref.putData(imageBytes);
      TaskSnapshot snap = await uploadTask;
      String downloadUrl = await snap.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      Fluttertoast.showToast(msg: 'อัปโหลดรูปภาพล้มเหลว: $e');
      throw e;
    }
  }
}
