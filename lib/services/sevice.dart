// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_box/controllers/vendor_controller.dart';

FirebaseAuth auth = FirebaseAuth.instance;
FirebaseFirestore firestore = FirebaseFirestore.instance;
FirebaseStorage storage = FirebaseStorage.instance;
VendorController vendorController = VendorController();
Future<SharedPreferences> sharedPreferences = SharedPreferences.getInstance();

double height = 825.h;
double width = 375.w;

styles({
  double? letterSpacing,
  double? fontSize = 14,
  double? height,
  FontWeight? fontWeight = FontWeight.w400,
  Color? color = Colors.black87,
}) {
  return GoogleFonts.josefinSans(
    height: height,
    letterSpacing: letterSpacing,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

List<String> sizeList = [];

// uploadImagToStorage(Uint8List image) async {
//   Reference ref = storage
//       .ref()
//       .child('storeImages')
//       .child(auth.currentUser!.uid);
//   UploadTask uploadTask = ref.putData(image);
//   TaskSnapshot snapshot = await uploadTask;
//   String downloadUrl = await snapshot.ref.getDownloadURL();
//   return downloadUrl;
// }

Future<String> uploadImagToStorage(Uint8List imageBytes) async {
  try {
    String fileName =
        'qr_${DateTime.now().millisecondsSinceEpoch}.png'; // Unique path
    Reference ref = FirebaseStorage.instance.ref().child('vendors/$fileName');

    // Set metadata เพื่อ fix content-type
    SettableMetadata metadata = SettableMetadata(
      contentType: 'image/png', // หรือ 'image/jpeg' ตาม format
    );

    UploadTask uploadTask = ref.putData(imageBytes, metadata);
    TaskSnapshot snapshot = await uploadTask; // Await เสร็จ

    String downloadUrl = await snapshot.ref.getDownloadURL();
    print('Upload success: $downloadUrl, size: ${imageBytes.lengthInBytes}');
    return downloadUrl;
  } catch (e) {
    print('Upload error: $e');
    rethrow;
  }
}

coverImageToStorage(Uint8List coverimage) async {
  Reference ref = storage.ref().child('coverPick').child(auth.currentUser!.uid);
  UploadTask uploadTask = ref.putData(coverimage);
  TaskSnapshot snapshot = await uploadTask;
  String downloadUrl = await snapshot.ref.getDownloadURL();
  return downloadUrl;
}

pickStoreImage(ImageSource source) async {
  final ImagePicker _imgPicker = ImagePicker();
  XFile? _file = await _imgPicker.pickImage(source: source);

  if (_file != null) {
    return await _file.readAsBytes();
  } else {
    Fluttertoast.showToast(msg: 'No image seleted');
  }
}
