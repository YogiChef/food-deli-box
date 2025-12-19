// ignore_for_file: use_build_context_synchronously, avoid_print
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor_box/auth/registor/__face_scan_page_state.dart';
import 'package:vendor_box/auth/registor/__id_scan_page_state.dart';
import 'package:vendor_box/auth/registor/vendor_registor_page.dart';
import 'package:vendor_box/auth/vendor_auth.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/widgets/button_widget.dart';
import 'package:vendor_box/widgets/input_textfield.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:country_state_city_picker/country_state_city_picker.dart';

class VendorProfileEditPage extends StatefulWidget {
  const VendorProfileEditPage({super.key});
  @override
  State<VendorProfileEditPage> createState() => _VendorProfileEditPageState();
}

class _VendorProfileEditPageState extends State<VendorProfileEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Init เป็น empty string เพื่อ avoid LateInitializationError
  String name = '';
  String ownerName = '';
  String email = '';
  String phone = '';
  String taxNumber = '';
  String addres = '';
  String zipcode = '';
  String countryValue = 'Thailand';
  String stateValue = '';
  String cityValue = '';
  String category = '';
  String bankName = '';
  String bankAccount = '';
  String promptPayId = '';
  // ข้อมูลบัตรประชาชน
  String idNumber = '';
  String birthDate = '';
  String cardOwnerName = '';
  Uint8List? image; // รูปโปรไฟล์หน้าร้าน (ใหม่)
  Uint8List? faceImage; // รูปสแกนเจ้าของร้าน (ใหม่)
  Uint8List? idCardImage; // รูปสแกนบัตรประชาชน (ใหม่)
  Uint8List? qrImage; // สำหรับ QR Code image (ใหม่)
  // URL รูปภาพปัจจุบัน (สำหรับแสดงผล)
  String? currentImageUrl;
  String? currentFaceImageUrl;
  String? currentIdCardImageUrl;
  String? currentQrImageUrl;
  final List<String> _taxOptions = ['YES', 'NO'];
  String? _taxStatus;
  final List<String> _bankList = [
    'ธนาคารกสิกรไทย (Kasikorn Bank)',
    'ธนาคารกรุงไทย (Krungthai Bank)',
    'ธนาคารไทยพาณิชย์ (SCB)',
    'ธนาคารกรุงศรีอยุธยา (Krungsri)',
    'ธนาคารทหารไทยธนชาต (TMBThanachart)',
    'ธนาคารกรุงเทพ (Bangkok Bank)',
    'ธนาคารออมสิน (Government Savings Bank)',
    'ธนาคารอาคารสงเคราะห์ (Government Housing Bank)',
  ];
  String? _bankDropdownValue;
  List<String> _categoryList = [];
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipcodeController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _promptPayIdController = TextEditingController();
  // Controller สำหรับข้อมูลบัตร
  final _idNumberController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _cardOwnerNameController = TextEditingController();
  bool _isLoading = true; // สำหรับโหลดข้อมูล

  // ฟังก์ชันอัปโหลดรูปภาพไปยัง Firebase Storage (เหมือนเดิม)
  Future<String> uploadImagToStorage(
    Uint8List imageBytes, {
    required String type,
  }) async {
    const int maxRetries = 1;
    for (int retry = 0; retry <= maxRetries; retry++) {
      try {
        if (_auth.currentUser == null) {
          print('Upload error: User not authenticated');
          return '';
        }
        if (imageBytes.isEmpty) {
          print('Upload error: Image bytes are empty for $type');
          return '';
        }
        String uid = _auth.currentUser!.uid;
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String fileName = '${uid}_${type}_$timestamp.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(
          'images/$fileName',
        );
        print(
          'Attempt ${retry + 1}: Uploading $type to path: ${ref.fullPath} (size: ${imageBytes.lengthInBytes} bytes)',
        );
        UploadTask uploadTask = ref.putData(imageBytes);
        TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
        if (snapshot.state == TaskState.success) {
          try {
            String downloadUrl = await snapshot.ref.getDownloadURL();
            print('Upload successful for $type: $downloadUrl');
            return downloadUrl;
          } catch (urlError) {
            print('Get download URL failed for $type: $urlError');
            await ref.delete().catchError((e) => print('Cleanup error: $e'));
            if (retry < maxRetries) continue;
            return '';
          }
        } else {
          print('Upload task state failed for $type: ${snapshot.state}');
          if (retry < maxRetries) continue;
          return '';
        }
      } on FirebaseException catch (e) {
        print(
          'Firebase Storage error for $type (attempt ${retry + 1}): ${e.code} - ${e.message}',
        );
        if (e.code == 'object-not-found' && retry < maxRetries) continue;
        return '';
      } catch (e) {
        print('General upload error for $type (attempt ${retry + 1}): $e');
        if (retry < maxRetries) continue;
        return '';
      }
    }
    return '';
  }

  // ฟังก์ชันอัปเดตข้อมูล vendor ใน Firestore
  Future<void> updateVendorData(Map<String, dynamic> vendorData) async {
    try {
      String uid = _auth.currentUser!.uid;
      await FirebaseFirestore.instance.collection('vendors').doc(uid).update({
        ...vendorData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Vendor data updated successfully: $uid');
    } catch (e) {
      print('Update vendor error: $e');
      rethrow;
    }
  }

  // โหลดข้อมูล vendor จาก Firestore
  Future<void> _loadVendorData() async {
    try {
      if (_auth.currentUser == null) {
        Get.to(() => const VendorAuthPage());
        return;
      }
      String uid = _auth.currentUser!.uid;
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(uid)
          .get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            name = data['bussinessName'] ?? '';
            ownerName = data['ownerName'] ?? '';
            email = data['email'] ?? '';
            phone = data['phone'] ?? '';
            taxNumber = data['taxNo'] == 'null' ? '' : data['taxNo'] ?? '';
            addres = data['address'] ?? '';
            zipcode = data['vzipcode'] ?? '';
            countryValue = data['country'] ?? 'Thailand';
            stateValue = data['state'] ?? '';
            cityValue = data['city'] ?? '';
            category = data['category'] ?? '';
            bankName = data['bankName'] ?? '';
            bankAccount = data['bankAccount'] == 'null'
                ? ''
                : data['bankAccount'] ?? '';
            promptPayId = data['promptPayId'] == 'null'
                ? ''
                : data['promptPayId'] ?? '';
            _taxStatus = data['taxStatus'] ?? 'NO';
            // ข้อมูลบัตร
            idNumber = data['idNumber'] ?? '';
            birthDate = data['birthDate'] ?? '';
            cardOwnerName = data['cardOwnerName'] ?? '';
            // URL รูปภาพปัจจุบัน
            currentImageUrl = data['image'];
            currentFaceImageUrl = data['faceImage'];
            currentIdCardImageUrl = data['idCardImage'];
            currentQrImageUrl = data['qrCodeImage'];
            // Set controllers
            _storeNameController.text = name;
            _ownerNameController.text = ownerName;
            _emailController.text = email;
            _phoneController.text = phone;
            _addressController.text = addres;
            _zipcodeController.text = zipcode;
            _taxNumberController.text = taxNumber;
            _bankAccountController.text = bankAccount;
            _promptPayIdController.text = promptPayId;
            _idNumberController.text = idNumber;
            _birthDateController.text = birthDate;
            _cardOwnerNameController.text = cardOwnerName;
            _categoryDropdownValue = category;
            _bankDropdownValue = bankName;
          });
        }
      } else {
        Fluttertoast.showToast(msg: 'ไม่พบข้อมูลโปรไฟล์ กรุณาลงทะเบียนใหม่');
        Get.to(() => const VendorRegistorPage());
      }
    } catch (e) {
      print('Load vendor error: $e');
      Fluttertoast.showToast(msg: 'เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> save() async {
    if (_formKey.currentState!.validate()) {
      // Assign ค่าก่อน validation
      name = _storeNameController.text.trim();
      ownerName = _ownerNameController.text.trim();
      email = _emailController.text.trim();
      phone = _phoneController.text.trim();
      addres = _addressController.text.trim();
      zipcode = _zipcodeController.text.trim();
      taxNumber = _taxNumberController.text.trim();
      category = _categoryDropdownValue ?? '';
      bankName = _bankDropdownValue ?? '';
      bankAccount = _bankAccountController.text.trim();
      promptPayId = _promptPayIdController.text.trim();
      // Validation สำหรับข้อมูลพื้นฐาน (ไม่บังคับสแกนใหม่ถ้ามีข้อมูลเก่า)
      if (name.isEmpty) {
        Fluttertoast.showToast(msg: 'กรุณากรอกชื่อร้าน');
        return;
      }
      if (ownerName.isEmpty) {
        Fluttertoast.showToast(msg: 'กรุณากรอกชื่อเจ้าของร้าน');
        return;
      }
      if (email.isEmpty) {
        Fluttertoast.showToast(msg: 'Email cannot be empty');
        return;
      }
      if (bankName.isNotEmpty &&
          bankAccount.isEmpty &&
          promptPayId.isEmpty &&
          (qrImage == null && currentQrImageUrl == null)) {
        Fluttertoast.showToast(
          msg: 'กรุณากรอกเลขบัญชี, PromptPay ID หรืออัปโหลด QR Code',
        );
        return;
      }
      // ถ้าไม่มีข้อมูลบัตรเก่าและไม่ได้สแกนใหม่ ให้เตือน
      if (idNumber.isEmpty &&
          idCardImage == null &&
          currentIdCardImageUrl == null) {
        Fluttertoast.showToast(msg: 'กรุณาสแกนบัตรประชาชนเพื่อยืนยันตัวตน');
        return;
      }
      EasyLoading.show(status: 'กำลังอัปเดต...');
      try {
        await _auth.currentUser!.reload();
        // Upload รูปภาพใหม่ถ้ามี (ไม่อัปโหลดถ้าไม่ได้เปลี่ยน)
        String imageUrl = currentImageUrl ?? '';
        if (image != null && image!.isNotEmpty) {
          print('Starting upload for store image...');
          imageUrl = await uploadImagToStorage(image!, type: 'store');
          if (imageUrl.isEmpty) {
            print('Store image upload failed - keeping old URL');
          }
        }
        String faceImageUrl = currentFaceImageUrl ?? '';
        if (faceImage != null && faceImage!.isNotEmpty) {
          print('Starting upload for face image...');
          faceImageUrl = await uploadImagToStorage(faceImage!, type: 'face');
          if (faceImageUrl.isEmpty) {
            print('Face image upload failed - keeping old URL');
          }
        }
        String idCardImageUrl = currentIdCardImageUrl ?? '';
        if (idCardImage != null && idCardImage!.isNotEmpty) {
          print('Starting upload for ID card image...');
          idCardImageUrl = await uploadImagToStorage(
            idCardImage!,
            type: 'idcard',
          );
          if (idCardImageUrl.isEmpty) {
            print('ID card image upload failed - keeping old URL');
          }
        }
        String qrImageUrl = currentQrImageUrl ?? '';
        if (qrImage != null && qrImage!.isNotEmpty) {
          print('Starting upload for QR image...');
          qrImageUrl = await uploadImagToStorage(qrImage!, type: 'qr');
          if (qrImageUrl.isEmpty) {
            print('QR image upload failed - keeping old URL');
          }
        }
        // สร้าง warning message ถ้ามี upload fail
        String warningMsg = '';
        if (imageUrl.isEmpty && image != null) warningMsg += 'รูปหน้าร้าน, ';
        if (faceImageUrl.isEmpty && faceImage != null)
          warningMsg += 'รูปใบหน้า, ';
        if (idCardImageUrl.isEmpty && idCardImage != null)
          warningMsg += 'รูปบัตรประชาชน, ';
        if (qrImageUrl.isEmpty && qrImage != null) warningMsg += 'QR Code, ';
        if (warningMsg.isNotEmpty) {
          warningMsg = warningMsg.substring(0, warningMsg.length - 2);
          warningMsg += ' อัปโหลดไม่สำเร็จ';
        }
        Map<String, dynamic> vendorData = {
          'category': category,
          'bussinessName': name,
          'ownerName': ownerName,
          'email': email,
          'phone': phone,
          'address': addres,
          'vzipcode': zipcode,
          'country': countryValue,
          'state': stateValue,
          'city': cityValue,
          'taxStatus': _taxStatus ?? 'NO',
          'taxNo': _taxStatus == 'YES' ? taxNumber : 'null',
          'image': imageUrl,
          'faceImage': faceImageUrl,
          'idCardImage': idCardImageUrl,
          'idNumber': idNumber,
          'birthDate': birthDate,
          'cardOwnerName': cardOwnerName,
          'bankName': bankName,
          'bankAccount': bankAccount.isNotEmpty ? bankAccount : 'null',
          'promptPayId': promptPayId.isNotEmpty ? promptPayId : 'null',
          'qrCodeImage': qrImageUrl,
        };
        await updateVendorData(vendorData);
        // Reset controllers ถ้าต้องการ (แต่สำหรับ edit อาจไม่ reset)
        if (mounted) setState(() {});
        EasyLoading.dismiss();
        Get.back(); // กลับไปหน้าก่อนหน้า
        Fluttertoast.showToast(
          msg: warningMsg.isEmpty
              ? 'อัปเดตโปรไฟล์สำเร็จ!'
              : 'อัปเดตสำเร็จ! $warningMsg (ข้อมูลพื้นฐานบันทึกแล้ว)',
        );
      } catch (e) {
        EasyLoading.dismiss();
        print('Update register error: $e');
        String errorMsg = e.toString();
        Fluttertoast.showToast(
          msg: 'เกิดข้อผิดพลาดในการอัปเดต: $errorMsg',
          backgroundColor: Colors.orange,
        );
      }
    }
  }

  String? _categoryDropdownValue;
  Future<void> getCategory() async {
    try {
      QuerySnapshot snapshot = await firestore.collection('categories').get();
      if (mounted) {
        setState(() {
          _categoryList.clear();
          for (var doc in snapshot.docs) {
            _categoryList.add(doc['categoryName'] as String? ?? 'Unknown');
          }
        });
      }
      print('Categories loaded: $_categoryList');
    } catch (e) {
      print('getCategory Error: $e');
      if (mounted) {
        setState(() {
          _categoryList = ['Electronics', 'Food', 'Clothing'];
        });
      }
      Fluttertoast.showToast(
        msg: 'ไม่สามารถโหลดหมวดหมู่ได้: $e (ใช้ค่าเริ่มต้น)',
      );
    }
  }

  Future<void> selectQRCamera() async {
    Uint8List? img = await vendorController.pickStoreImage(ImageSource.camera);
    if (img != null) {
      print('Picked QR Image size: ${img.lengthInBytes} bytes');
      if (img.lengthInBytes == 0) {
        Fluttertoast.showToast(msg: 'ไม่สามารถ pick รูปได้ กรุณาลองใหม่');
        return;
      }
      setState(() {
        qrImage = img;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Init ค่าเริ่มต้น
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getCategory();
      _loadVendorData(); // โหลดข้อมูล
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _zipcodeController.dispose();
    _taxNumberController.dispose();
    _bankAccountController.dispose();
    _promptPayIdController.dispose();
    _idNumberController.dispose();
    _birthDateController.dispose();
    _cardOwnerNameController.dispose();
    super.dispose();
  }

  // Widget สำหรับแสดงรูปภาพ (รองรับ URL หรือ Uint8List)
  Widget _buildImageWidget(
    String? url,
    Uint8List? bytes, {
    required String placeholderAsset,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    ImageProvider imageProvider;
    if (bytes != null) {
      imageProvider = MemoryImage(bytes);
    } else if (url != null && url.isNotEmpty) {
      imageProvider = NetworkImage(url);
    } else {
      imageProvider = AssetImage(placeholderAsset);
    }
    return Container(
      height: 100.h,
      width: 100.w,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10.r),
        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
      ),
      child: bytes == null && url == null
          ? InkWell(
              onTap: onTap,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 40, color: Colors.grey),
                    Text(
                      label,
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'แก้ไขโปรไฟล์',
          style: styles(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header สำหรับรูปโปรไฟล์ร้าน
              SizedBox(
                width: double.infinity,
                height: 170.h,
                child: Center(
                  child: Stack(
                    children: [
                      Container(
                        height: 170.h,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(0),
                          image: DecorationImage(
                            image: image == null && currentImageUrl != null
                                ? NetworkImage(currentImageUrl!)
                                : (image != null
                                      ? MemoryImage(image!)
                                      : AssetImage('images/viewcover.jpg')),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 100.w,
                              height: 100.h,
                              child: Stack(
                                alignment: Alignment.bottomLeft,
                                children: [
                                  ClipOval(
                                    child: Image(
                                      image:
                                          faceImage == null &&
                                              currentFaceImageUrl != null
                                          ? NetworkImage(currentFaceImageUrl!)
                                          : (faceImage != null
                                                ? MemoryImage(faceImage!)
                                                : AssetImage(
                                                    'images/profile.jpg',
                                                  )),
                                      fit: BoxFit.cover,
                                      width: 100.w,
                                      height: 100.h,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              CircleAvatar(
                                                radius: 50,
                                                backgroundImage: AssetImage(
                                                  'images/profile.jpg',
                                                ),
                                              ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.cyan.shade400,
                                      radius: 18,
                                      child: IconButton(
                                        onPressed: () async {
                                          final result =
                                              await Navigator.push<Uint8List?>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const FaceScanPage(),
                                                ),
                                              );
                                          if (result != null && mounted) {
                                            setState(() {
                                              faceImage = result;
                                            });
                                            Fluttertoast.showToast(
                                              msg: 'อัปเดตสแกนใบหน้าเรียบร้อย!',
                                            );
                                          }
                                        },
                                        icon: Icon(
                                          Icons.face_retouching_natural,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 20,
                        child: CircleAvatar(
                          backgroundColor: Colors.cyan.shade400,
                          radius: 18.r,
                          child: IconButton(
                            onPressed: () => chooseOption(context),
                            icon: image != null
                                ? Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : Icon(
                                    CupertinoIcons.photo,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Section สำหรับข้อมูลเจ้าของร้าน (สแกนบัตร)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 12.h),
                    Text(
                      'ข้อมูลร้าน',
                      style: styles(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildImageWidget(
                            currentIdCardImageUrl,
                            idCardImage,
                            placeholderAsset:
                                'images/id_placeholder.jpg', // สมมติมี asset นี้
                            icon: Icons.credit_card,
                            label: 'สแกนบัตรประชาชน',
                            onTap: () async {
                              final result =
                                  await Navigator.push<Map<String, dynamic>?>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const IdScanPage(),
                                    ),
                                  );
                              if (result != null && mounted) {
                                final file = File(result['path']!);
                                final bytes = await file.readAsBytes();
                                setState(() {
                                  idCardImage = bytes;
                                  idNumber =
                                      result['idNumber'] ??
                                      idNumber; // เก็บเก่าถ้าไม่มีใหม่
                                  birthDate = result['birthDate'] ?? birthDate;
                                  cardOwnerName =
                                      result['cardOwnerName'] ?? cardOwnerName;
                                  _idNumberController.text = idNumber;
                                  _birthDateController.text = birthDate;
                                  _cardOwnerNameController.text = cardOwnerName;
                                });
                                Fluttertoast.showToast(
                                  msg:
                                      'อัปเดตสแกนบัตรเรียบร้อย! ชื่อ: $cardOwnerName',
                                );
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 10.w),
                        SizedBox(width: width * .4),
                      ],
                    ),
                    // แสดงข้อมูลที่สแกนได้ (editable)
                    if (idCardImage != null ||
                        currentIdCardImageUrl != null) ...[
                      SizedBox(height: 10.h),
                      InputTextfield(
                        controller: _cardOwnerNameController,
                        hintText: 'ชื่อจากบัตร',
                        textInputType: TextInputType.text,
                        enabled: true, // สามารถแก้ไขได้
                        prefixIcon: Icon(Icons.person, color: Colors.blue),
                        onChanged: (value) =>
                            setState(() => cardOwnerName = value),
                      ),
                      InputTextfield(
                        controller: _idNumberController,
                        hintText: 'เลขบัตรประชาชน',
                        textInputType: TextInputType.number,
                        enabled: true,
                        prefixIcon: Icon(Icons.credit_card, color: Colors.blue),
                        onChanged: (value) => setState(() => idNumber = value),
                        validator: (value) =>
                            value!.isEmpty || value.length != 13
                            ? 'เลขบัตรต้อง 13 หลัก'
                            : null,
                      ),
                      InputTextfield(
                        controller: _birthDateController,
                        hintText: 'วันเกิด',
                        textInputType: TextInputType.datetime,
                        enabled: true,
                        prefixIcon: Icon(Icons.cake, color: Colors.blue),
                        onChanged: (value) => setState(() => birthDate = value),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              // ส่วนอื่นๆ (เหมือน register แต่ enabled สำหรับ edit)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: [
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _categoryDropdownValue,
                      hint: const Text('เลือกหมวดหมู่'),
                      items: _categoryList.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _categoryDropdownValue = value),
                      validator: (value) =>
                          value == null ? 'กรุณาเลือกหมวดหมู่' : null,
                    ),
                    SizedBox(height: 20.h),
                    // ชื่อร้าน
                    InputTextfield(
                      controller: _storeNameController,
                      hintText: 'ชื่อร้าน',
                      textInputType: TextInputType.text,
                      prefixIcon: Icon(
                        Icons.store,
                        color: Colors.yellow.shade900,
                      ),
                      onChanged: (value) => setState(() => name = value),
                      validator: (value) =>
                          value!.isEmpty ? 'กรุณากรอกชื่อร้าน' : null,
                    ),
                    InputTextfield(
                      controller: _emailController,
                      hintText: 'Email',
                      textInputType: TextInputType.emailAddress,
                      enabled: false, // Email มักไม่แก้ไข
                      prefixIcon: Icon(
                        Icons.email,
                        color: Colors.cyan.shade600,
                      ),
                      onChanged: (value) => setState(() => email = value),
                      validator: (value) => value!.isEmpty
                          ? 'Please enter your email address'
                          : (!value.isValidEmail() ? 'Invalid email' : null),
                    ),
                    InputTextfield(
                      controller: _phoneController,
                      hintText: 'เบอร์โทร',
                      textInputType: TextInputType.phone,
                      prefixIcon: Icon(
                        Icons.phone,
                        color: Colors.green.shade300,
                      ),
                      onChanged: (value) => setState(() => phone = value),
                      validator: (value) =>
                          value!.isEmpty ? 'Please Enter your Phone' : null,
                    ),
                    SizedBox(height: 10.h),
                    InputTextfield(
                      controller: _ownerNameController,
                      hintText: 'ชื่อเจ้าของร้าน',
                      textInputType: TextInputType.text,
                      prefixIcon: Icon(
                        Icons.person,
                        color: Colors.yellow.shade900,
                      ),
                      onChanged: (value) => setState(() => ownerName = value),
                      validator: (value) =>
                          value!.isEmpty ? 'กรุณากรอกชื่อเจ้าของร้าน' : null,
                    ),
                    SizedBox(height: 20.h),
                    // Bank dropdown
                    Padding(
                      padding: const EdgeInsets.only(left: 0, right: 0),
                      child: DropdownButtonFormField<String>(
                        value: _bankDropdownValue,
                        hint: const Text('เลือกธนาคาร'),
                        isExpanded: true,
                        items: _bankList.map((String bank) {
                          return DropdownMenuItem<String>(
                            value: bank,
                            child: SizedBox(
                              width: double.maxFinite,
                              child: Text(
                                bank,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                                maxLines: 1,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _bankDropdownValue = value),
                        validator: (value) => null,
                      ),
                    ),
                    if (_bankDropdownValue != null) ...[
                      InputTextfield(
                        controller: _bankAccountController,
                        hintText: 'เลขบัญชี',
                        textInputType: TextInputType.number,
                        prefixIcon: const Icon(
                          Icons.account_balance,
                          color: Colors.blue,
                        ),
                        onChanged: (value) =>
                            setState(() => bankAccount = value),
                        validator: (value) => value!.isEmpty
                            ? 'เลขบัญชี'
                            : (value.length < 10
                                  ? 'เลขบัญชีต้องมีอย่างน้อย 10 หลัก'
                                  : null),
                      ),
                    ],
                    InputTextfield(
                      controller: _promptPayIdController,
                      hintText: 'PromptPay ID',
                      textInputType: TextInputType.phone,
                      prefixIcon: const Icon(
                        Icons.phone_android,
                        color: Colors.blue,
                      ),
                      onChanged: (value) => setState(() => promptPayId = value),
                      validator: (value) => null,
                    ),
                    // QR upload
                    if (_bankDropdownValue != null &&
                        _promptPayIdController.text.trim().isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 12.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QR Code แอปธนาคาร',
                              style: styles(
                                color: Colors.cyan.shade600,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Center(
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  _buildImageWidget(
                                    currentQrImageUrl,
                                    qrImage,
                                    placeholderAsset:
                                        'images/qr_placeholder.jpg', // สมมติมี asset
                                    icon: Icons.qr_code,
                                    label: 'อัปโหลด QR Code',
                                    onTap: () => chooseQRImageOption(context),
                                  ),
                                  if (qrImage == null &&
                                      currentQrImageUrl == null)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.cyan.shade400,
                                        radius: 18.r,
                                        child: IconButton(
                                          onPressed: () =>
                                              chooseQRImageOption(context),
                                          icon: Icon(
                                            Icons.add_a_photo,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 10.h),
                    InputTextfield(
                      controller: _addressController,
                      hintText: 'บ้านเลขที่',
                      textInputType: TextInputType.text,
                      prefixIcon: const Icon(
                        Icons.location_pin,
                        color: Colors.pink,
                      ),
                      onChanged: (value) => setState(() => addres = value),
                      validator: (value) => value!.isEmpty
                          ? 'กรุณากรอกบ้านเลขที่ หมู่ที่ '
                          : null,
                    ),
                    InputTextfield(
                      controller: _zipcodeController,
                      hintText: 'zipcode',
                      textInputType: TextInputType.number,
                      prefixIcon: const Icon(
                        Icons.code_rounded,
                        color: Colors.amber,
                      ),
                      onChanged: (value) => setState(() => zipcode = value),
                      validator: (value) =>
                          value!.isEmpty ? 'Please Enter your zipcode' : null,
                    ),
                    SizedBox(height: 12.h),
                    SelectState(
                      style: styles(color: Colors.black54, fontSize: 12.sp),
                      onCountryChanged: (value) => setState(() {
                        countryValue = value;
                        if (value != 'Thailand') {
                          stateValue = '';
                          cityValue = '';
                        }
                      }),
                      onStateChanged: (value) =>
                          setState(() => stateValue = value),
                      onCityChanged: (value) =>
                          setState(() => cityValue = value),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tax Registered?',
                          style: styles(
                            color: Colors.cyan.shade600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: SizedBox(
                            width: 100,
                            child: DropdownButtonFormField(
                              value: _taxStatus,
                              hint: Text(
                                'Select',
                                style: styles(
                                  color: Colors.cyan.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              items: _taxOptions
                                  .map<DropdownMenuItem<String>>(
                                    (String value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: styles(color: Colors.deepOrange),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _taxStatus = value),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_taxStatus == 'YES') ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextFormField(
                          controller: _taxNumberController,
                          keyboardType: TextInputType.number,
                          onChanged: (value) =>
                              setState(() => taxNumber = value),
                          validator: (value) => value!.isEmpty
                              ? 'Please Tax Number must not be empty'
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Tax Number',
                            labelStyle: styles(color: Colors.cyan.shade600),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 70),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: BottonWidget(
          label: 'อัปเดต',
          style: styles(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: Colors.white,
          ),
          icon: Icons.update,
          press: save,
        ),
      ),
    );
  }

  Future<dynamic> chooseOption(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Choose option',
            style: styles(
              fontWeight: FontWeight.w500,
              color: Colors.yellow.shade900,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                InkWell(
                  onTap: () {
                    selectCameca();
                    Navigator.pop(context);
                  },
                  splashColor: Colors.yellow.shade900,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.yellow.shade900,
                        ),
                      ),
                      Text(
                        'Camera',
                        style: styles(
                          fontWeight: FontWeight.w500,
                          color: Colors.cyan.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    selectGallery();
                    Navigator.pop(context);
                  },
                  splashColor: Colors.yellow.shade900,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.green.shade900,
                        ),
                      ),
                      Text(
                        'Gallery',
                        style: styles(
                          fontWeight: FontWeight.w500,
                          color: Colors.cyan.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => removeImage('store'),
                  splashColor: Colors.yellow.shade900,
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.remove_circle, color: Colors.red),
                      ),
                      Text(
                        'Remove',
                        style: styles(
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<dynamic> chooseQRImageOption(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เลือก QR Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.yellow),
                title: const Text('Camera'),
                onTap: () {
                  selectQRCamera();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Gallery'),
                onTap: () {
                  selectQRGallery();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle, color: Colors.red),
                title: const Text('Remove'),
                onTap: () {
                  removeImage('qr');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> selectQRGallery() async {
    Uint8List? img = await vendorController.pickStoreImage(ImageSource.gallery);
    if (img != null) {
      setState(() {
        qrImage = img;
      });
    }
  }

  Future<void> selectCameca() async {
    Uint8List? img = await vendorController.pickStoreImage(ImageSource.camera);
    if (img != null && img.isNotEmpty) {
      print('Store image picked from camera: ${img.lengthInBytes} bytes');
      setState(() {
        image = img;
      });
    } else {
      print('Store image pick from camera failed or empty');
      Fluttertoast.showToast(msg: 'ไม่สามารถถ่ายรูปได้ กรุณาลองใหม่');
    }
  }

  Future<void> selectGallery() async {
    final img = await vendorController.pickStoreImage(ImageSource.gallery);
    if (img != null && img.isNotEmpty) {
      print('Store image picked from gallery: ${img.lengthInBytes} bytes');
      setState(() {
        image = img;
      });
    } else {
      print('Store image pick from gallery failed or empty');
      Fluttertoast.showToast(msg: 'ไม่สามารถเลือกภาพได้ กรุณาลองใหม่');
    }
  }

  void removeImage(String type) {
    setState(() {
      switch (type) {
        case 'store':
          image = null;
          break;
        case 'qr':
          qrImage = null;
          break;
      }
    });
    Navigator.pop(context);
  }
}
