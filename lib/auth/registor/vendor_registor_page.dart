// ignore_for_file: use_build_context_synchronously, avoid_print
import 'dart:io'; // สำหรับ Fi
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
import 'package:vendor_box/auth/vendor_auth.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/widgets/button_widget.dart';
import 'package:vendor_box/widgets/input_textfield.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:country_state_city_picker/country_state_city_picker.dart'; // สำหรับตรวจสอบเลขบัตร (optional ถ้าติดตั้ง)

class VendorRegistorPage extends StatefulWidget {
  const VendorRegistorPage({super.key});
  @override
  State<VendorRegistorPage> createState() => _VendorRegistorPageState();
}

class _VendorRegistorPageState extends State<VendorRegistorPage> {
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
  // เพิ่มตัวแปรสำหรับข้อมูลบัตรประชาชน
  String idNumber = ''; // เลขบัตรประชาชน (13 หลัก)
  String birthDate = ''; // วันเกิดจากบัตร
  String cardOwnerName = ''; // ชื่อจากบัตร (เพื่อเปรียบเทียบกับ ownerName)
  Uint8List? image; // รูปโปรไฟล์หน้าร้าน
  Uint8List? faceImage; // รูปสแกนเจ้าของร้าน
  Uint8List? idCardImage; // รูปสแกนบัตรประชาชน
  Uint8List? qrImage; // สำหรับ QR Code image
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
  final _storeNameController = TextEditingController(); // ชื่อร้าน
  final _ownerNameController = TextEditingController(); // ชื่อเจ้าของร้าน
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipcodeController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _promptPayIdController = TextEditingController();
  // เพิ่ม Controller สำหรับข้อมูลบัตร (แสดงผลหลังสแกน)
  final _idNumberController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _cardOwnerNameController = TextEditingController();
  // ฟังก์ชันอัปโหลดรูปภาพไปยัง Firebase Storage - ปรับปรุงเพื่อจัดการ error และ retry
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
        // Path ง่าย ๆ: images/filename เพื่อหลีกเลี่ยงปัญหา subdir
        Reference ref = FirebaseStorage.instance.ref().child(
          'images/$fileName',
        );
        print(
          'Attempt ${retry + 1}: Uploading $type to path: ${ref.fullPath} (size: ${imageBytes.lengthInBytes} bytes)',
        );
        UploadTask uploadTask = ref.putData(imageBytes);
        TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
        if (snapshot.state == TaskState.success) {
          // Separate try for getDownloadURL
          try {
            String downloadUrl = await snapshot.ref.getDownloadURL();
            print('Upload successful for $type: $downloadUrl');
            return downloadUrl;
          } catch (urlError) {
            print('Get download URL failed for $type: $urlError');
            // ลบไฟล์ถ้า get URL fail
            await ref.delete().catchError((e) => print('Cleanup error: $e'));
            if (retry < maxRetries) continue; // Retry
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
        if (e.code == 'object-not-found' && retry < maxRetries)
          continue; // Retry on this error
        return '';
      } catch (e) {
        print('General upload error for $type (attempt ${retry + 1}): $e');
        if (retry < maxRetries) continue;
        return '';
      }
    }
    return '';
  }

  Future<void> saveVendorData(Map<String, dynamic> vendorData) async {
    try {
      String uid = _auth.currentUser!.uid;
      vendorData['vendorId'] = uid;
      vendorData['uid'] = uid;
      await FirebaseFirestore.instance.collection('vendors').doc(uid).set({
        ...vendorData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Vendor data saved successfully: $uid');
    } catch (e) {
      print('Save vendor error: $e');
      rethrow;
    }
  }

  // ฟังก์ชัน _parseIdCardData สำหรับ VendorRegistorPage (Main page) - ใช้ global vars และ setState controllers
  // void _parseIdCardData(String recognizedText) {
  //   try {
  //     // ล้างข้อมูลเก่า
  //     idNumber = '';
  //     birthDate = '';
  //     cardOwnerName = '';
  //     if (recognizedText.isEmpty) {
  //       Fluttertoast.showToast(msg: 'OCR ไม่พบข้อความ ลองสแกนชัดๆ ในที่สว่าง');
  //       return;
  //     }
  //     String text = recognizedText.replaceAll(RegExp(r'\s+'), ' ');
  //     print('Cleaned TEXT: $text');

  //     // หาเลขบัตร (เดิม)
  //     RegExp idRegex = RegExp(r'(\d\s*){13}');
  //     Match? idMatch = idRegex.firstMatch(text);
  //     if (idMatch != null) {
  //       idNumber = idMatch.group(0)!.replaceAll(RegExp(r'\s'), '');
  //       if (idNumber.length == 13) {
  //         final thaiIdValidator = ThaiIdCardNumbers();
  //         if (!thaiIdValidator.validate(idNumber)) {
  //           Fluttertoast.showToast(msg: 'เลขบัตรไม่ถูกต้อง ลองสแกนใหม่');
  //           idNumber = '';
  //         } else {
  //           print('Valid ID: $idNumber');
  //         }
  //       } else {
  //         idNumber = '';
  //       }
  //     }
  //     print('Parsed ID: $idNumber');

  //     // หา First Name (loose: handle "Neme" / "Nane" as "Name")
  //     String firstName = '';
  //     RegExp firstRegex = RegExp(
  //       r'(?:Name|Neme|Nane)[\s:]*Mr\.\s*([A-Za-z\u0E00-\u0E7F]+?)(?=\s*(?:Last|นามสกุล|เลขบัตร|\d|$))',
  //     );
  //     Match? firstMatch = firstRegex.firstMatch(text);
  //     if (firstMatch != null) {
  //       firstName = firstMatch.group(1)!.trim();
  //     }
  //     print('Parsed First: $firstName');

  //     // หา Last Name (loose: handle "nane" / "nanme" / "nanse")
  //     String lastName = '';
  //     RegExp lastRegex = RegExp(
  //       r'Last\s*(?:nane|nanme|nanse|name)[\s:]*([A-Za-z\u0E00-\u0E7F]+?)(?=\s*(?:Lñ|Date|เกิด|เลข|\d|$))',
  //     );
  //     Match? lastMatch = lastRegex.firstMatch(text);
  //     if (lastMatch != null) {
  //       lastName = lastMatch.group(1)!.trim();
  //     }
  //     print('Parsed Last: $lastName');

  //     // Concat full name
  //     cardOwnerName = firstName.isNotEmpty ? firstName : '';
  //     if (lastName.isNotEmpty) {
  //       cardOwnerName += (cardOwnerName.isNotEmpty ? ' ' : '') + lastName;
  //     }
  //     print('Parsed Full Name: $cardOwnerName');

  //     // หาวันเกิด (loose: handle "Data of Brth" / "Deta of Bith" / "Date of Brth")
  //     RegExp birthRegex = RegExp(
  //       r'(?:Date of Birth|Data of Brth|Deta of Bith|Date of Brth|Data of Brth)[\s:]*(\d{1,2})\s*([A-Za-z]{3,}\.?)\s*(\d{4})',
  //     );
  //     Match? birthMatch = birthRegex.firstMatch(text);
  //     if (birthMatch != null) {
  //       String day = birthMatch.group(1)!;
  //       String month = birthMatch.group(2)!;
  //       String year = birthMatch.group(3)!;
  //       if (year.length == 4 &&
  //           int.tryParse(year) != null &&
  //           int.parse(year) > 2500) {
  //         year = (int.parse(year) - 543).toString();
  //       }
  //       birthDate = '$day/$month/$year';
  //       print('Parsed Birth: $birthDate');
  //     }
  //     print('Parsed Birth: $birthDate');

  //     // อัปเดต UI
  //     if (mounted) {
  //       setState(() {
  //         _idNumberController.text = idNumber;
  //         _birthDateController.text = birthDate;
  //         _cardOwnerNameController.text = cardOwnerName;
  //       });
  //       bool isComplete =
  //           idNumber.isNotEmpty &&
  //           cardOwnerName.isNotEmpty &&
  //           birthDate.isNotEmpty;
  //       String successMsg = 'สแกนสำเร็จ! ';
  //       if (idNumber.isNotEmpty) successMsg += 'เลขบัตร: $idNumber ';
  //       if (cardOwnerName.isNotEmpty) successMsg += 'ชื่อ: $cardOwnerName ';
  //       if (birthDate.isNotEmpty) successMsg += 'วันเกิด: $birthDate';
  //       if (isComplete) {
  //         Fluttertoast.showToast(msg: '$successMsg (ครบถ้วน!)');
  //       } else {
  //         Fluttertoast.showToast(msg: successMsg + ' (ไม่ครบ ลองสแกนใหม่)');
  //       }
  //     }
  //   } catch (parseError) {
  //     print('Parse Error: $parseError');
  //     Fluttertoast.showToast(msg: 'Parse ล้มเหลว ลองสแกนใหม่');
  //   }
  // }

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
      // เพิ่ม validation สำหรับบัตรประชาชน
      if (idCardImage == null) {
        Fluttertoast.showToast(msg: 'กรุณาสแกนบัตรประชาชน');
        return;
      }
      if (idNumber.isEmpty) {
        Fluttertoast.showToast(msg: 'กรุณาสแกนบัตรให้ชัดเจนเพื่อดึงเลขบัตร');
        return;
      }
      if (ownerName.isNotEmpty && cardOwnerName.isNotEmpty) {
        // Normalize: lower + remove extra space
        String normOwner = ownerName.toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        String normCard = cardOwnerName.toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        // Check first name match (tolerant)
        String ownerFirst = normOwner.split(' ').first;
        String cardFirst = normCard.split(' ').first;
        if (!normOwner.contains(cardFirst) || !normCard.contains(ownerFirst)) {
          Fluttertoast.showToast(
            msg: 'ชื่อบันชีไม่ตรงกับบัตร (ตรวจ first name) กรุณาตรวจสอบ',
            timeInSecForIosWeb: 2,
          );
          return;
        }
        print('Name match OK: Owner="$ownerName" vs Card="$cardOwnerName"');
      }
      if (faceImage == null) {
        Fluttertoast.showToast(msg: 'กรุณาสแกนใบหน้า');
        return;
      }
      if (name.isEmpty) {
        Fluttertoast.showToast(msg: 'กรุณากรอกชื่อร้าน');
        return;
      }
      if (ownerName.isEmpty) {
        Fluttertoast.showToast(msg: 'กรุณากรอกชื่อบันชี');
        return;
      }
      if (email.isEmpty) {
        Fluttertoast.showToast(msg: 'Email cannot be empty');
        return;
      }
      if (bankName.isNotEmpty &&
          bankAccount.isEmpty &&
          promptPayId.isEmpty &&
          qrImage == null) {
        Fluttertoast.showToast(
          msg: 'กรุณากรอกเลขบัญชี, PromptPay ID หรืออัปโหลด QR Code',
        );
        return;
      }
      EasyLoading.show(status: 'Please wait');
      try {
        await _auth.currentUser!.reload();
        // Upload images one by one with error handling และ logging
        String imageUrl = '';
        if (image != null && image!.isNotEmpty) {
          print('Starting upload for store image...');
          imageUrl = await uploadImagToStorage(image!, type: 'store');
          if (imageUrl.isEmpty) {
            print('Store image upload failed - continuing with empty URL');
          }
        } else {
          print('No store image to upload');
        }
        String faceImageUrl = '';
        if (faceImage != null && faceImage!.isNotEmpty) {
          print('Starting upload for face image...');
          faceImageUrl = await uploadImagToStorage(faceImage!, type: 'face');
          if (faceImageUrl.isEmpty) {
            print('Face image upload failed - continuing with empty URL');
          }
        } else {
          print('No face image to upload (but validation passed?)');
        }
        // เพิ่ม upload สำหรับบัตรประชาชน
        String idCardImageUrl = '';
        if (idCardImage != null && idCardImage!.isNotEmpty) {
          print('Starting upload for ID card image...');
          idCardImageUrl = await uploadImagToStorage(
            idCardImage!,
            type: 'idcard',
          );
          if (idCardImageUrl.isEmpty) {
            print('ID card image upload failed - continuing with empty URL');
          }
        } else {
          print('No ID card image to upload (but validation passed?)');
        }
        String qrImageUrl = '';
        if (qrImage != null && qrImage!.isNotEmpty) {
          print('Starting upload for QR image...');
          qrImageUrl = await uploadImagToStorage(qrImage!, type: 'qr');
          if (qrImageUrl.isEmpty) {
            print('QR image upload failed - continuing with empty URL');
          }
        } else {
          print('No QR image to upload');
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
          warningMsg = warningMsg.substring(
            0,
            warningMsg.length - 2,
          ); // ลบ comma สุดท้าย
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
          'idCardImage': idCardImageUrl, // เพิ่ม URL รูปบัตร
          'idNumber': idNumber, // เพิ่มเลขบัตร
          'birthDate': birthDate, // เพิ่มวันเกิด
          'cardOwnerName': cardOwnerName, // เพิ่มชื่อจากบัตร
          'approved': false,
          'bankName': bankName,
          'bankAccount': bankAccount.isNotEmpty ? bankAccount : 'null',
          'promptPayId': promptPayId.isNotEmpty ? promptPayId : 'null',
          'qrCodeImage': qrImageUrl,
        };
        await saveVendorData(vendorData);
        // Reset form - แก้ null check
        if (_formKey.currentState != null) {
          _formKey.currentState!.reset();
        }
        _storeNameController.clear();
        _ownerNameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _addressController.clear();
        _zipcodeController.clear();
        _taxNumberController.clear();
        _bankAccountController.clear();
        _promptPayIdController.clear();
        // เพิ่ม reset สำหรับบัตร
        _idNumberController.clear();
        _birthDateController.clear();
        _cardOwnerNameController.clear();
        image = null;
        faceImage = null;
        idCardImage = null;
        qrImage = null;
        idNumber = '';
        birthDate = '';
        cardOwnerName = '';
        if (mounted) setState(() {});
        EasyLoading.dismiss();
        Get.to(() => const VendorAuthPage());
        Fluttertoast.showToast(
          msg: warningMsg.isEmpty
              ? 'ลงทะเบียนสำเร็จ!'
              : 'ลงทะเบียนสำเร็จ! $warningMsg (ข้อมูลพื้นฐานบันทึกแล้ว)',
        );
      } catch (e) {
        EasyLoading.dismiss();
        print('Save register error: $e');
        String errorMsg = e.toString();
        Fluttertoast.showToast(
          msg: 'เกิดข้อผิดพลาดในการบันทึก: $errorMsg (ข้อมูลพื้นฐานบันทึกแล้ว)',
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
    name = '';
    ownerName = '';
    email = '';
    phone = '';
    taxNumber = '';
    addres = '';
    zipcode = '';
    countryValue = 'Thailand';
    stateValue = '';
    cityValue = '';
    category = '';
    bankName = '';
    bankAccount = '';
    promptPayId = '';
    // เพิ่ม init สำหรับบัตร
    idNumber = '';
    birthDate = '';
    cardOwnerName = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_auth.currentUser == null) {
        Get.to(() => const VendorAuthPage());
        return;
      }
      email = _auth.currentUser!.email ?? '';
      _emailController.text = email;
      getCategory();
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
    // เพิ่ม dispose สำหรับบัตร
    _idNumberController.dispose();
    _birthDateController.dispose();
    _cardOwnerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                            image: image == null
                                ? AssetImage('images/viewcover.jpg')
                                : MemoryImage(image!),
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
                                  faceImage != null
                                      ? ClipOval(
                                          child: Image.memory(
                                            faceImage!,
                                            fit: BoxFit.cover,
                                            width: 100.w,
                                            height: 100.h,
                                          ),
                                        )
                                      : const CircleAvatar(
                                          radius: 50,
                                          backgroundImage: AssetImage(
                                            'images/profile.jpg',
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
                                              msg: 'สแกนใบหน้าเรียบร้อย!',
                                            );
                                          }
                                        },
                                        icon: const Icon(
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
                        top: 20,
                        left: 20,
                        child: CircleAvatar(
                          backgroundColor: Colors.cyan.shade400,
                          radius: 16.r,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.arrow_back_ios,
                              size: 20.r,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 20,
                        child: CircleAvatar(
                          backgroundColor: Colors.cyan.shade400,
                          radius: 18.r,
                          child: IconButton(
                            onPressed: () {
                              chooseOption(context);
                            },
                            icon: image != null
                                ? const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : const Icon(
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
              // Section สำหรับข้อมูลเจ้าของร้าน (เพิ่มส่วนสแกนบัตร)
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
                          child: Container(
                            height: 100.h,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10.r),
                              image: idCardImage != null
                                  ? DecorationImage(
                                      image: MemoryImage(idCardImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: idCardImage == null
                                  ? Colors.grey.shade100
                                  : null,
                            ),
                            child: idCardImage == null
                                ? InkWell(
                                    onTap: () async {
                                      final result =
                                          await Navigator.push<
                                            Map<String, dynamic>?
                                          >(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const IdScanPage(),
                                            ),
                                          );
                                      if (result != null && mounted) {
                                        final file = File(result['path']!);
                                        final bytes = await file.readAsBytes();
                                        setState(() {
                                          idCardImage = bytes;
                                          idNumber = result['idNumber'] ?? '';
                                          birthDate = result['birthDate'] ?? '';
                                          cardOwnerName =
                                              result['cardOwnerName'] ?? '';
                                          _idNumberController.text = idNumber;
                                          _birthDateController.text = birthDate;
                                          _cardOwnerNameController.text =
                                              cardOwnerName;
                                        });
                                        // OCR ด้วย fromFilePath (แก้ปัญหา metadata)
                                        //   final inputImage =
                                        //       InputImage.fromFilePath(result);
                                        //   final textRecognizer = TextRecognizer(
                                        //     script: TextRecognitionScript.latin,
                                        //   );
                                        //   try {
                                        //     final recognizedText =
                                        //         await textRecognizer.processImage(
                                        //           inputImage,
                                        //         );
                                        //     String fullText = '';
                                        //     for (TextBlock block
                                        //         in recognizedText.blocks) {
                                        //       fullText += '${block.text}\n';
                                        //     }
                                        //     print(
                                        //       'RAW OCR TEXT: $fullText',
                                        //     ); // Debug: ดู console หลังสแกน
                                        //     _parseIdCardData(fullText);
                                        //   } catch (e) {
                                        //     print('OCR Error: $e');
                                        //     Fluttertoast.showToast(
                                        //       msg: 'OCR ล้มเหลว: $e ลองสแกนใหม่',
                                        //     );
                                        //   } finally {
                                        //     textRecognizer.close();
                                        //   }
                                        Fluttertoast.showToast(
                                          msg:
                                              'สแกนสำเร็จและยืนยันข้อมูล! ชื่อ: $cardOwnerName',
                                        );
                                      }
                                    },
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.credit_card,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                          Text(
                                            'สแกนบัตรประชาชน',
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        SizedBox(width: width * .4),
                      ],
                    ),
                    // แสดงข้อมูลที่สแกนได้ (optional, editable)
                    if (idCardImage != null) ...[
                      SizedBox(height: 10.h),
                      InputTextfield(
                        controller: _cardOwnerNameController,
                        hintText: 'ชื่อจากบัตร (auto)',
                        textInputType: TextInputType.text,
                        enabled: false, // หรือ true ถ้าต้องการแก้ไข
                        prefixIcon: Icon(Icons.person, color: Colors.blue),
                        onChanged: (value) =>
                            setState(() => cardOwnerName = value),
                      ),
                      InputTextfield(
                        controller: _idNumberController,
                        hintText: 'เลขบัตรประชาชน (auto)',
                        textInputType: TextInputType.number,
                        enabled: false,
                        prefixIcon: Icon(Icons.credit_card, color: Colors.blue),
                        onChanged: (value) => setState(() => idNumber = value),
                        validator: (value) =>
                            value!.isEmpty || value.length != 13
                            ? 'เลขบัตรต้อง 13 หลัก'
                            : null,
                      ),
                      InputTextfield(
                        controller: _birthDateController,
                        hintText: 'วันเกิด (auto)',
                        textInputType: TextInputType.datetime,
                        enabled: false,
                        prefixIcon: Icon(Icons.cake, color: Colors.blue),
                        onChanged: (value) => setState(() => birthDate = value),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              // ส่วนอื่นๆ
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: [
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _categoryDropdownValue,
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
                      enabled: false,
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
                      hintText: 'ชื่อบันชี',
                      textInputType: TextInputType.text,
                      prefixIcon: Icon(
                        Icons.person,
                        color: Colors.yellow.shade900,
                      ),
                      onChanged: (value) => setState(() => ownerName = value),
                      validator: (value) => value!.isEmpty
                          ? 'กรุณากรอกชื่อเจ้าของบันขีให้ตรงกับสมุดบันชี'
                          : null,
                    ),
                    SizedBox(height: 20.h),
                    // Bank dropdown
                    Padding(
                      padding: const EdgeInsets.only(left: 0, right: 0),
                      child: DropdownButtonFormField<String>(
                        initialValue: _bankDropdownValue,
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
                    // QR upload if needed
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
                                  qrImage != null
                                      ? Container(
                                          height: 100.h,
                                          width: 100.w,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10.r,
                                            ),
                                            image: DecorationImage(
                                              image: MemoryImage(qrImage!),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          height: 100.h,
                                          width: 100.w,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(
                                              10.r,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.qr_code,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.cyan.shade400,
                                      radius: 18.r,
                                      child: IconButton(
                                        onPressed: () =>
                                            chooseQRImageOption(context),
                                        icon: const Icon(
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
          label: 'Save',
          style: styles(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: Colors.white,
          ),
          icon: Icons.save,
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
                  onTap: () {
                    remove();
                  },
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

  void remove() {
    setState(() {
      image = null;
    });
    Navigator.pop(context);
  }
}
