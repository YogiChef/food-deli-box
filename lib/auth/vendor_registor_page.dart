// // ignore_for_file: use_build_context_synchronously

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:get/get.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:vendor_box/auth/vendor_auth.dart';
// import 'package:vendor_box/services/sevice.dart';
// import 'package:vendor_box/widgets/button_widget.dart';
// import 'package:vendor_box/widgets/input_textfield.dart';
// import 'package:flutter_easyloading/flutter_easyloading.dart';
// import 'package:country_state_city_picker/country_state_city_picker.dart';

// class VendorRegistorPage extends StatefulWidget {
//   const VendorRegistorPage({super.key});

//   @override
//   State<VendorRegistorPage> createState() => _VendorRegistorPageState();
// }

// class _VendorRegistorPageState extends State<VendorRegistorPage> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   late String name;
//   late String email;
//   late String phone;
//   late String taxNumber;
//   late String addres;
//   late String zipcode;
//   late String countryValue;
//   late String stateValue;
//   late String cityValue;
//   late String category;
//   late String bankName;
//   late String bankAccount;
//   late String promptPayId; // ใหม่

//   Uint8List? image;

//   final List<String> _taxOptions = ['YES', 'NO'];
//   String? _taxStatus;
//   final List<String> _bankList = [
//     'ธนาคารกสิกรไทย (Kasikorn Bank)',
//     'ธนาคารกรุงไทย (Krungthai Bank)',
//     'ธนาคารไทยพาณิชย์ (SCB)',
//     'ธนาคารกรุงศรีอยุธยา (Krungsri)',
//     'ธนาคารทหารไทยธนชาต (TMBThanachart)',
//     'ธนาคารกรุงเทพ (Bangkok Bank)',
//     'ธนาคารออมสิน (Government Savings Bank)',
//     'ธนาคารอาคารสงเคราะห์ (Government Housing Bank)',
//   ];
//   String? _bankDropdownValue;
//   List<String> _categoryList = [];
//   bool _obscureText = true;

//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   // final _passwordController = TextEditingController(); // ลบ password field เนื่องจากเป็น after login
//   final _phoneController = TextEditingController();
//   final _addressController = TextEditingController();
//   final _zipcodeController = TextEditingController();
//   final _taxNumberController = TextEditingController();
//   final _bankAccountController =
//       TextEditingController(); // ใหม่สำหรับเลขบัญชี/พร้อมเพย์
//   final _promptPayIdController = TextEditingController(); // ใหม่

//   Future<void> saveVendorData(Map<String, dynamic> vendorData) async {
//     try {
//       // ใช้ uid จาก current user (after login)
//       String uid = FirebaseAuth.instance.currentUser!.uid;

//       // Update vendorData ด้วย uid
//       vendorData['vendorId'] = uid;
//       vendorData['uid'] = uid;

//       // Create/Update document ใน vendors/{uid}
//       await FirebaseFirestore.instance.collection('vendors').doc(uid).set({
//         ...vendorData,
//         'createdAt': FieldValue.serverTimestamp(),
//       });

//       print(
//         'Vendor data saved successfully: $uid (vendorId: $uid, email: $email)',
//       );
//     } catch (e) {
//       print('Save vendor error: $e');
//       rethrow;
//     }
//   }

//   save() async {
//     if (_formKey.currentState!.validate()) {
//       EasyLoading.show(status: 'Please wait');
//       try {
//         print('Save started – email: $email'); // Debug loading (no password)
//         await auth.currentUser!.reload(); // Reload current user
//         // ดึงค่า fields (trim เพื่อ clean space)
//         name = _nameController.text.trim();
//         // email = auth.currentUser!.email ?? ''; // ใช้ email จาก current user (fixed)
//         email = _emailController.text.trim(); // หรือจาก form ถ้าต้องการ update
//         // password = _passwordController.text.trim(); // ลบ
//         phone = _phoneController.text.trim();
//         addres = _addressController.text.trim();
//         zipcode = _zipcodeController.text.trim();
//         taxNumber = _taxNumberController.text.trim();
//         category = _categoryDropdownValue ?? ''; // จาก dropdown
//         bankName = _bankDropdownValue ?? ''; // ใหม่
//         bankAccount = _bankAccountController.text.trim(); // ใหม่
//         promptPayId = _promptPayIdController.text.trim();

//         // Check email ไม่ว่าง (extra safe)
//         if (email.isEmpty) {
//           throw Exception('Email cannot be empty');
//         }

//         // Check bank ถ้าต้องการ (optional แต่ถ้าเลือกธนาคารแล้วต้องมีเลขบัญชี)
//         if (bankName.isNotEmpty && bankAccount.isEmpty) {
//           throw Exception('กรุณากรอกเลขบัญชีหรือพร้อมเพย์');
//         }

//         // vendorData สำหรับ doc (email จาก current user หรือ form)
//         Map<String, dynamic> vendorData = {
//           'category': category,
//           'bussinessName': name,
//           'email': email, // ใช้จาก form หรือ currentUser.email
//           'phone': phone,
//           'address': addres,
//           'vzipcode': zipcode,
//           'country': countryValue,
//           'state': stateValue,
//           'city': cityValue,
//           'taxStatus': _taxStatus ?? 'NO',
//           'taxNo': _taxStatus == 'YES' ? taxNumber : 'null',
//           'image': image != null
//               ? await uploadImagToStorage(image!)
//               : '', // upload image ถ้ามี
//           'approved': false,
//           // ใหม่: Bank fields
//           'bankName': bankName,
//           'bankAccount': bankAccount.isNotEmpty ? bankAccount : 'null',
//           'promptPayId': promptPayId.isNotEmpty ? promptPayId : 'null',
//           // vendorId set ใน saveVendorData
//         };

//         print('VendorData ready: $vendorData'); // Debug vendorData

//         // เรียก saveVendorData (save doc ด้วย uid ปัจจุบัน)
//         await saveVendorData(vendorData);

//         print('Save success – Going to VendorAuthPage'); // Debug

//         // Reset form
//         _formKey.currentState!.reset();
//         _nameController.clear();
//         _emailController.clear();
//         // _passwordController.clear(); // ลบ
//         _phoneController.clear();
//         _addressController.clear();
//         _zipcodeController.clear();
//         _taxNumberController.clear();
//         _bankAccountController.clear(); // ใหม่
//         _promptPayIdController.clear(); // ใหม่
//         image = null;
//         setState(() {}); // Refresh UI

//         EasyLoading.dismiss();
//         Get.to(() => const VendorAuthPage()); // Navigate ไป auth page
//         Fluttertoast.showToast(msg: 'ลงทะเบียนสำเร็จ!');
//       } catch (e) {
//         EasyLoading.dismiss();
//         print('Save register error: $e'); // Debug print
//         Fluttertoast.showToast(
//           msg: 'เกิดข้อผิดพลาด: $e',
//           backgroundColor: Colors.red,
//         );
//       }
//     }
//   }

//   String? _categoryDropdownValue;

//   Future<void> getCategory() async {
//     // เปลี่ยนเป็น async void
//     try {
//       QuerySnapshot snapshot = await firestore.collection('categories').get();
//       setState(() {
//         _categoryList.clear();
//         for (var doc in snapshot.docs) {
//           _categoryList.add(doc['categoryName'] as String? ?? 'Unknown');
//         }
//       });
//       print('Categories loaded: $_categoryList'); // Debug
//     } catch (e) {
//       print('getCategory Error: $e'); // Log error
//       // Fallback: ใช้ default categories ถ้า fail (ไม่ crash UI)
//       setState(() {
//         _categoryList = [
//           'Electronics',
//           'Food',
//           'Clothing',
//         ]; // Default list หรือ []
//       });
//       Fluttertoast.showToast(
//         msg: 'ไม่สามารถโหลดหมวดหมู่ได้: $e (ใช้ค่าเริ่มต้น)',
//       );
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     // Check if user is logged in
//     if (auth.currentUser == null) {
//       // ถ้าไม่มี user ให้ navigate ไป login page
//       Get.to(() => const VendorAuthPage()); // หรือ login page ที่เหมาะสม
//       return;
//     }
//     // Set email from current user
//     email = auth.currentUser!.email ?? '';
//     _emailController.text = email;
//     getCategory();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     // _passwordController.dispose(); // ลบ
//     _phoneController.dispose();
//     _addressController.dispose();
//     _zipcodeController.dispose();
//     _taxNumberController.dispose();
//     _bankAccountController.dispose(); // ใหม่
//     _promptPayIdController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SingleChildScrollView(
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Center(
//                 child: Stack(
//                   children: [
//                     Container(
//                       height: 170,
//                       width: double.infinity,
//                       decoration: BoxDecoration(
//                         color: Colors.grey.shade300,
//                         borderRadius: BorderRadius.circular(0),
//                         image: const DecorationImage(
//                           image: AssetImage('images/viewcover.jpg'),
//                           fit: BoxFit.cover,
//                         ),
//                       ),
//                       child: Row(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Stack(
//                             alignment: Alignment.bottomLeft,
//                             children: [
//                               image != null
//                                   ? CircleAvatar(
//                                       radius: 50,
//                                       backgroundColor: Colors.yellow.shade900,
//                                       backgroundImage: MemoryImage(image!),
//                                     )
//                                   : const CircleAvatar(
//                                       radius: 50,
//                                       backgroundImage: AssetImage(
//                                         'images/profile.jpg',
//                                       ),
//                                     ),
//                               Positioned(
//                                 right: 0,
//                                 bottom: 0,
//                                 child: CircleAvatar(
//                                   backgroundColor: Colors.cyan.shade400,
//                                   radius: 18,
//                                   child: IconButton(
//                                     onPressed: () {
//                                       chooseOption(context);
//                                     },
//                                     icon: image != null
//                                         ? const Icon(
//                                             Icons.edit,
//                                             color: Colors.white,
//                                             size: 18,
//                                           )
//                                         : const Icon(
//                                             CupertinoIcons.photo,
//                                             color: Colors.white,
//                                             size: 18,
//                                           ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                     Positioned(
//                       top: 20,
//                       left: 20,
//                       child: CircleAvatar(
//                         backgroundColor: Colors.cyan.shade400,
//                         radius: 16.r,
//                         child: IconButton(
//                           onPressed: () {
//                             Navigator.pop(context);
//                           },
//                           icon: Icon(
//                             Icons.arrow_back_ios,
//                             size: 20.r,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
//                 child: DropdownButtonFormField<String>(
//                   value: _categoryDropdownValue,
//                   hint: const Text('เลือกหมวดหมู่'),
//                   items: _categoryList.map((String category) {
//                     return DropdownMenuItem<String>(
//                       value: category,
//                       child: Text(category),
//                     );
//                   }).toList(),
//                   onChanged: (value) =>
//                       setState(() => _categoryDropdownValue = value),
//                   validator: (value) =>
//                       value == null ? 'กรุณาเลือกหมวดหมู่' : null,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               InputTextfield(
//                 controller: _nameController,
//                 hintText: 'Enter Full Name',
//                 textInputType: TextInputType.text,
//                 prefixIcon: Icon(Icons.person, color: Colors.yellow.shade900),
//                 onChanged: (value) {
//                   setState(() {
//                     name = value;
//                   });
//                 },
//                 validator: (value) {
//                   if (value!.isEmpty) {
//                     return 'Please Enter your name';
//                   } else {
//                     return null;
//                   }
//                 },
//               ),
//               InputTextfield(
//                 controller: _emailController,
//                 hintText:
//                     'Enter Email', // Read-only หรือ enabled ถ้าต้องการ update
//                 textInputType: TextInputType.emailAddress,
//                 enabled: false, // Make read-only เพื่อป้องกันเปลี่ยน email
//                 prefixIcon: Icon(Icons.email, color: Colors.cyan.shade600),
//                 onChanged: (value) {
//                   setState(() {
//                     email = value;
//                   });
//                 },
//                 validator: (value) {
//                   if (value!.isEmpty) {
//                     return 'Please enter your email address';
//                   } else if (!value.isValidEmail()) {
//                     // Fix: ใช้ !isValidEmail() แทน logic ซ้ำ
//                     return 'Invalid email';
//                   }
//                   return null;
//                 },
//               ),
//               // InputTextfield for password ลบออกเพราะเป็น after login
//               InputTextfield(
//                 controller: _phoneController,
//                 hintText: 'Enter Your Phone',
//                 textInputType: TextInputType.phone,
//                 prefixIcon: Icon(Icons.phone, color: Colors.green.shade300),
//                 onChanged: (value) {
//                   setState(() {
//                     phone = value;
//                   });
//                 },
//                 validator: (value) {
//                   if (value!.isEmpty) {
//                     return 'Please Enter your Phone';
//                   } else {
//                     return null;
//                   }
//                 },
//               ),
//               // ใหม่: Dropdown สำหรับเลือกธนาคาร
//               Padding(
//                 padding: const EdgeInsets.only(left: 20, right: 20),
//                 child: DropdownButtonFormField<String>(
//                   value: _bankDropdownValue,
//                   hint: const Text('เลือกธนาคาร (ถ้ามี)'),
//                   isExpanded:
//                       true, // เพิ่ม isExpanded เพื่อให้ dropdown ขยายเต็มความกว้างและจัดการ overflow ภายใน
//                   items: _bankList.map((String bank) {
//                     return DropdownMenuItem<String>(
//                       value: bank,
//                       child: SizedBox(
//                         // ใช้ SizedBox เพื่อกำหนด bounded width สำหรับ Text
//                         width: double
//                             .maxFinite, // ใช้ maxFinite เพื่อ fit กับ parent constraints
//                         child: Text(
//                           bank,
//                           overflow: TextOverflow.ellipsis, // แสดง ... ถ้าล้น
//                           style: const TextStyle(
//                             fontSize: 14,
//                           ), // กำหนดขนาด font เล็กเพื่อลดความเสี่ยง
//                           maxLines:
//                               1, // จำกัด 1 บรรทัดเพื่อป้องกัน multi-line overflow
//                         ),
//                       ),
//                     );
//                   }).toList(),
//                   onChanged: (value) =>
//                       setState(() => _bankDropdownValue = value),
//                   validator: (value) =>
//                       null, // Optional field, ไม่ validate ที่นี่
//                 ),
//               ),
//               // ใหม่: Conditional field สำหรับเลขบัญชี/พร้อมเพย์
//               _bankDropdownValue != null
//                   ? Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 20),
//                       child: InputTextfield(
//                         controller: _bankAccountController,
//                         hintText: 'กรอกเลขบัญชีหรือพร้อมเพย์ ID',
//                         textInputType: TextInputType.number,
//                         prefixIcon: const Icon(
//                           Icons.account_balance,
//                           color: Colors.blue,
//                         ),
//                         onChanged: (value) {
//                           setState(() {
//                             bankAccount = value;
//                           });
//                         },
//                         validator: (value) {
//                           if (value!.isEmpty) {
//                             return 'กรุณากรอกเลขบัญชีหรือพร้อมเพย์';
//                           } else if (value.length < 10) {
//                             // Basic validation สำหรับเลขบัญชีไทย (อย่างน้อย 10 หลัก)
//                             return 'เลขบัญชีต้องมีอย่างน้อย 10 หลัก';
//                           } else {
//                             return null;
//                           }
//                         },
//                       ),
//                     )
//                   : const SizedBox(),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 20),
//                 child: InputTextfield(
//                   controller: _promptPayIdController,
//                   hintText: 'กรอก PromptPay ID (เบอร์โทร/อีเมล)',
//                   textInputType: TextInputType.phone,
//                   prefixIcon: const Icon(
//                     Icons.phone_android,
//                     color: Colors.blue,
//                   ),
//                   onChanged: (value) {
//                     setState(() {
//                       promptPayId = value;
//                     });
//                   },
//                   validator: (value) => null, // Optional field
//                 ),
//               ),
//               InputTextfield(
//                 controller: _addressController,
//                 hintText: 'Enter Your Address',
//                 textInputType: TextInputType.text,
//                 prefixIcon: const Icon(Icons.location_pin, color: Colors.pink),
//                 onChanged: (value) {
//                   setState(() {
//                     addres = value;
//                   });
//                 },
//                 validator: (value) {
//                   if (value!.isEmpty) {
//                     return 'Please Enter your address';
//                   } else {
//                     return null;
//                   }
//                 },
//               ),
//               InputTextfield(
//                 controller: _zipcodeController,
//                 hintText: 'Enter Your zipcode',
//                 textInputType: TextInputType.number,
//                 prefixIcon: const Icon(Icons.code_rounded, color: Colors.amber),
//                 onChanged: (value) {
//                   setState(() {
//                     zipcode = value;
//                   });
//                 },
//                 validator: (value) {
//                   if (value!.isEmpty) {
//                     return 'Please Enter your zipcode';
//                   } else {
//                     return null;
//                   }
//                 },
//               ),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 20),
//                 child: SelectState(
//                   style: styles(color: Colors.black54),
//                   onCountryChanged: (value) {
//                     setState(() {
//                       countryValue = value;
//                     });
//                   },
//                   onStateChanged: (value) {
//                     setState(() {
//                       stateValue = value;
//                     });
//                   },
//                   onCityChanged: (value) {
//                     setState(() {
//                       cityValue = value;
//                     });
//                   },
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 20),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Tax Registered?',
//                       style: styles(color: Colors.cyan.shade600, fontSize: 16),
//                     ),
//                     const SizedBox(width: 10),
//                     Flexible(
//                       child: SizedBox(
//                         width: 100,
//                         child: DropdownButtonFormField(
//                           hint: Text(
//                             'Select',
//                             style: styles(
//                               color: Colors.cyan.shade600,
//                               fontSize: 16,
//                             ),
//                           ),
//                           items: _taxOptions
//                               .map<DropdownMenuItem<String>>(
//                                 (String value) => DropdownMenuItem<String>(
//                                   value: value,
//                                   child: Text(
//                                     value,
//                                     style: styles(color: Colors.deepOrange),
//                                   ),
//                                 ),
//                               )
//                               .toList(),
//                           onChanged: (value) {
//                             setState(() {
//                               _taxStatus = value;
//                             });
//                           },
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               _taxStatus == 'YES'
//                   ? Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 20),
//                       child: TextFormField(
//                         keyboardType: TextInputType.number,
//                         onChanged: (value) {
//                           setState(() {
//                             taxNumber = value;
//                           });
//                         },
//                         validator: (value) {
//                           if (value!.isEmpty) {
//                             return 'Please Tax Number must not be empty';
//                           } else {
//                             return null;
//                           }
//                         },
//                         decoration: InputDecoration(
//                           labelText: 'Tax Number',
//                           labelStyle: styles(color: Colors.cyan.shade600),
//                         ),
//                       ),
//                     )
//                   : const SizedBox(),

//               const SizedBox(height: 70),
//             ],
//           ),
//         ),
//       ),
//       bottomSheet: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         child: BottonWidget(
//           label: 'Save',
//           style: styles(
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             letterSpacing: 1,
//             color: Colors.white,
//           ),
//           icon: Icons.save,
//           press: save,
//         ),
//       ),
//     );
//   }

//   Future<dynamic> chooseOption(BuildContext context) {
//     return showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text(
//             'Choose option',
//             style: styles(
//               fontWeight: FontWeight.w500,
//               color: Colors.yellow.shade900,
//             ),
//           ),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: [
//                 InkWell(
//                   onTap: () {
//                     selectCameca();
//                     Navigator.pop(context);
//                   },
//                   splashColor: Colors.yellow.shade900,
//                   child: Row(
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Icon(
//                           Icons.camera_alt_outlined,
//                           color: Colors.yellow.shade900,
//                         ),
//                       ),
//                       Text(
//                         'Camera',
//                         style: styles(
//                           fontWeight: FontWeight.w500,
//                           color: Colors.cyan.shade400,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 InkWell(
//                   onTap: () {
//                     selectGallery();
//                     Navigator.pop(context);
//                   },
//                   splashColor: Colors.yellow.shade900,
//                   child: Row(
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Icon(
//                           Icons.image_outlined,
//                           color: Colors.green.shade900,
//                         ),
//                       ),
//                       Text(
//                         'Gallery',
//                         style: styles(
//                           fontWeight: FontWeight.w500,
//                           color: Colors.cyan.shade400,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 InkWell(
//                   onTap: () {
//                     remove();
//                   },
//                   splashColor: Colors.yellow.shade900,
//                   child: Row(
//                     children: [
//                       const Padding(
//                         padding: EdgeInsets.all(8.0),
//                         child: Icon(Icons.remove_circle, color: Colors.red),
//                       ),
//                       Text(
//                         'Remove',
//                         style: styles(
//                           fontWeight: FontWeight.w500,
//                           color: Colors.red,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   selectCameca() async {
//     Uint8List img = await vendorController.pickStoreImage(ImageSource.camera);
//     setState(() {
//       image = img;
//     });
//   }

//   selectGallery() async {
//     final img = await vendorController.pickStoreImage(ImageSource.gallery);

//     setState(() {
//       image = img;
//     });
//   }

//   remove() {
//     setState(() {
//       image = null; // Clear image
//     });
//     Navigator.pop(context);
//   }
// }

// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor_box/auth/vendor_auth.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/widgets/button_widget.dart';
import 'package:vendor_box/widgets/input_textfield.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:country_state_city_picker/country_state_city_picker.dart';

class VendorRegistorPage extends StatefulWidget {
  const VendorRegistorPage({super.key});

  @override
  State<VendorRegistorPage> createState() => _VendorRegistorPageState();
}

class _VendorRegistorPageState extends State<VendorRegistorPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String name;
  late String email;
  late String phone;
  late String taxNumber;
  late String addres;
  late String zipcode;
  late String countryValue;
  late String stateValue;
  late String cityValue;
  late String category;
  late String bankName;
  late String bankAccount;
  late String promptPayId; // ใหม่

  Uint8List? image;
  Uint8List? qrImage; // ใหม่: สำหรับ QR Code image

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
  bool _obscureText = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  // final _passwordController = TextEditingController(); // ลบ password field เนื่องจากเป็น after login
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipcodeController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _bankAccountController =
      TextEditingController(); // ใหม่สำหรับเลขบัญชี/พร้อมเพย์
  final _promptPayIdController = TextEditingController(); // ใหม่

  Future<void> saveVendorData(Map<String, dynamic> vendorData) async {
    try {
      // ใช้ uid จาก current user (after login)
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // Update vendorData ด้วย uid
      vendorData['vendorId'] = uid;
      vendorData['uid'] = uid;

      // Create/Update document ใน vendors/{uid}
      await FirebaseFirestore.instance.collection('vendors').doc(uid).set({
        ...vendorData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print(
        'Vendor data saved successfully: $uid (vendorId: $uid, email: $email)',
      );
    } catch (e) {
      print('Save vendor error: $e');
      rethrow;
    }
  }

  save() async {
    if (_formKey.currentState!.validate()) {
      EasyLoading.show(status: 'Please wait');
      try {
        print('Save started – email: $email'); // Debug loading (no password)
        await auth.currentUser!.reload(); // Reload current user
        // ดึงค่า fields (trim เพื่อ clean space)
        name = _nameController.text.trim();
        // email = auth.currentUser!.email ?? ''; // ใช้ email จาก current user (fixed)
        email = _emailController.text.trim(); // หรือจาก form ถ้าต้องการ update
        // password = _passwordController.text.trim(); // ลบ
        phone = _phoneController.text.trim();
        addres = _addressController.text.trim();
        zipcode = _zipcodeController.text.trim();
        taxNumber = _taxNumberController.text.trim();
        category = _categoryDropdownValue ?? ''; // จาก dropdown
        bankName = _bankDropdownValue ?? ''; // ใหม่
        bankAccount = _bankAccountController.text.trim(); // ใหม่
        promptPayId = _promptPayIdController.text.trim();

        // Check email ไม่ว่าง (extra safe)
        if (email.isEmpty) {
          throw Exception('Email cannot be empty');
        }

        // Check bank ถ้าต้องการ (optional แต่ถ้าเลือกธนาคารแล้วต้องมีเลขบัญชี)
        if (bankName.isNotEmpty && bankAccount.isEmpty) {
          throw Exception('กรุณากรอกเลขบัญชีหรือพร้อมเพย์');
        }

        // ใหม่: Check ถ้าเลือกธนาคารแล้ว ต้องมีอย่างน้อย bankAccount, promptPayId หรือ qrImage
        if (bankName.isNotEmpty &&
            bankAccount.isEmpty &&
            promptPayId.isEmpty &&
            qrImage == null) {
          throw Exception(
            'กรุณากรอกเลขบัญชี, PromptPay ID หรืออัปโหลด QR Code',
          );
        }

        // vendorData สำหรับ doc (email จาก current user หรือ form)
        Map<String, dynamic> vendorData = {
          'category': category,
          'bussinessName': name,
          'email': email, // ใช้จาก form หรือ currentUser.email
          'phone': phone,
          'address': addres,
          'vzipcode': zipcode,
          'country': countryValue,
          'state': stateValue,
          'city': cityValue,
          'taxStatus': _taxStatus ?? 'NO',
          'taxNo': _taxStatus == 'YES' ? taxNumber : 'null',
          'image': image != null
              ? await uploadImagToStorage(image!)
              : '', // upload image ถ้ามี
          'approved': false,
          // ใหม่: Bank fields
          'bankName': bankName,
          'bankAccount': bankAccount.isNotEmpty ? bankAccount : 'null',
          'promptPayId': promptPayId.isNotEmpty ? promptPayId : 'null',
          // ใหม่: QR Code image
          'qrCodeImage': qrImage != null
              ? await uploadImagToStorage(qrImage!)
              : '',
          // vendorId set ใน saveVendorData
        };

        print('VendorData ready: $vendorData'); // Debug vendorData

        // เรียก saveVendorData (save doc ด้วย uid ปัจจุบัน)
        await saveVendorData(vendorData);

        print('Save success – Going to VendorAuthPage'); // Debug

        // Reset form
        _formKey.currentState!.reset();
        _nameController.clear();
        _emailController.clear();
        // _passwordController.clear(); // ลบ
        _phoneController.clear();
        _addressController.clear();
        _zipcodeController.clear();
        _taxNumberController.clear();
        _bankAccountController.clear(); // ใหม่
        _promptPayIdController.clear(); // ใหม่
        image = null;
        qrImage = null; // ใหม่
        setState(() {}); // Refresh UI

        EasyLoading.dismiss();
        Get.to(() => const VendorAuthPage()); // Navigate ไป auth page
        Fluttertoast.showToast(msg: 'ลงทะเบียนสำเร็จ!');
      } catch (e) {
        EasyLoading.dismiss();
        print('Save register error: $e'); // Debug print
        Fluttertoast.showToast(
          msg: 'เกิดข้อผิดพลาด: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  String? _categoryDropdownValue;

  Future<void> getCategory() async {
    // เปลี่ยนเป็น async void
    try {
      QuerySnapshot snapshot = await firestore.collection('categories').get();
      setState(() {
        _categoryList.clear();
        for (var doc in snapshot.docs) {
          _categoryList.add(doc['categoryName'] as String? ?? 'Unknown');
        }
      });
      print('Categories loaded: $_categoryList'); // Debug
    } catch (e) {
      print('getCategory Error: $e'); // Log error
      // Fallback: ใช้ default categories ถ้า fail (ไม่ crash UI)
      setState(() {
        _categoryList = [
          'Electronics',
          'Food',
          'Clothing',
        ]; // Default list หรือ []
      });
      Fluttertoast.showToast(
        msg: 'ไม่สามารถโหลดหมวดหมู่ได้: $e (ใช้ค่าเริ่มต้น)',
      );
    }
  }

  Future<void> selectQRCamera() async {
    Uint8List? img = await vendorController.pickStoreImage(ImageSource.camera);
    if (img != null) {
      print(
        'Picked QR Image size: ${img.lengthInBytes} bytes',
      ); // Debug: ตรวจขนาด
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
    // Check if user is logged in
    if (auth.currentUser == null) {
      // ถ้าไม่มี user ให้ navigate ไป login page
      Get.to(() => const VendorAuthPage()); // หรือ login page ที่เหมาะสม
      return;
    }
    // Set email from current user
    email = auth.currentUser!.email ?? '';
    _emailController.text = email;
    getCategory();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    // _passwordController.dispose(); // ลบ
    _phoneController.dispose();
    _addressController.dispose();
    _zipcodeController.dispose();
    _taxNumberController.dispose();
    _bankAccountController.dispose(); // ใหม่
    _promptPayIdController.dispose();
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
              Center(
                child: Stack(
                  children: [
                    Container(
                      height: 170,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(0),
                        image: const DecorationImage(
                          image: AssetImage('images/viewcover.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Stack(
                            alignment: Alignment.bottomLeft,
                            children: [
                              image != null
                                  ? CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.yellow.shade900,
                                      backgroundImage: MemoryImage(image!),
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
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(
                            Icons.arrow_back_ios,
                            size: 20.r,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                child: DropdownButtonFormField<String>(
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
              ),
              const SizedBox(height: 20),
              InputTextfield(
                controller: _nameController,
                hintText: 'Enter Full Name',
                textInputType: TextInputType.text,
                prefixIcon: Icon(Icons.person, color: Colors.yellow.shade900),
                onChanged: (value) {
                  setState(() {
                    name = value;
                  });
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please Enter your name';
                  } else {
                    return null;
                  }
                },
              ),
              InputTextfield(
                controller: _emailController,
                hintText:
                    'Enter Email', // Read-only หรือ enabled ถ้าต้องการ update
                textInputType: TextInputType.emailAddress,
                enabled: false, // Make read-only เพื่อป้องกันเปลี่ยน email
                prefixIcon: Icon(Icons.email, color: Colors.cyan.shade600),
                onChanged: (value) {
                  setState(() {
                    email = value;
                  });
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter your email address';
                  } else if (!value.isValidEmail()) {
                    // Fix: ใช้ !isValidEmail() แทน logic ซ้ำ
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              // InputTextfield for password ลบออกเพราะเป็น after login
              InputTextfield(
                controller: _phoneController,
                hintText: 'Enter Your Phone',
                textInputType: TextInputType.phone,
                prefixIcon: Icon(Icons.phone, color: Colors.green.shade300),
                onChanged: (value) {
                  setState(() {
                    phone = value;
                  });
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please Enter your Phone';
                  } else {
                    return null;
                  }
                },
              ),
              // ใหม่: Dropdown สำหรับเลือกธนาคาร
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: DropdownButtonFormField<String>(
                  value: _bankDropdownValue,
                  hint: const Text('เลือกธนาคาร (ถ้ามี)'),
                  isExpanded:
                      true, // เพิ่ม isExpanded เพื่อให้ dropdown ขยายเต็มความกว้างและจัดการ overflow ภายใน
                  items: _bankList.map((String bank) {
                    return DropdownMenuItem<String>(
                      value: bank,
                      child: SizedBox(
                        // ใช้ SizedBox เพื่อกำหนด bounded width สำหรับ Text
                        width: double
                            .maxFinite, // ใช้ maxFinite เพื่อ fit กับ parent constraints
                        child: Text(
                          bank,
                          overflow: TextOverflow.ellipsis, // แสดง ... ถ้าล้น
                          style: const TextStyle(
                            fontSize: 14,
                          ), // กำหนดขนาด font เล็กเพื่อลดความเสี่ยง
                          maxLines:
                              1, // จำกัด 1 บรรทัดเพื่อป้องกัน multi-line overflow
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _bankDropdownValue = value),
                  validator: (value) =>
                      null, // Optional field, ไม่ validate ที่นี่
                ),
              ),
              // ใหม่: Conditional field สำหรับเลขบัญชี/พร้อมเพย์
              _bankDropdownValue != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: InputTextfield(
                        controller: _bankAccountController,
                        hintText: 'กรอกเลขบัญชีหรือพร้อมเพย์ ID',
                        textInputType: TextInputType.number,
                        prefixIcon: const Icon(
                          Icons.account_balance,
                          color: Colors.blue,
                        ),
                        onChanged: (value) {
                          setState(() {
                            bankAccount = value;
                          });
                        },
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'กรุณากรอกเลขบัญชีหรือพร้อมเพย์';
                          } else if (value.length < 10) {
                            // Basic validation สำหรับเลขบัญชีไทย (อย่างน้อย 10 หลัก)
                            return 'เลขบัญชีต้องมีอย่างน้อย 10 หลัก';
                          } else {
                            return null;
                          }
                        },
                      ),
                    )
                  : const SizedBox(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InputTextfield(
                  controller: _promptPayIdController,
                  hintText: 'กรอก PromptPay ID (เบอร์โทร/อีเมล)',
                  textInputType: TextInputType.phone,
                  prefixIcon: const Icon(
                    Icons.phone_android,
                    color: Colors.blue,
                  ),
                  onChanged: (value) {
                    setState(() {
                      promptPayId = value;
                    });
                  },
                  validator: (value) => null, // Optional field
                ),
              ),
              // ใหม่: Conditional QR Upload Field (แสดงถ้าเลือก bank แต่ promptPayId ว่าง)
              if (_bankDropdownValue != null &&
                  _promptPayIdController.text.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'อัปโหลด QR Code จากแอปธนาคาร (ถ้าไม่มี PromptPay)',
                        style: styles(
                          color: Colors.cyan.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            qrImage != null
                                ? Container(
                                    height: 100.h,
                                    width: 100.w,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
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
                                      borderRadius: BorderRadius.circular(10),
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
                                  onPressed: () => chooseQRImageOption(context),
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
              InputTextfield(
                controller: _addressController,
                hintText: 'Enter Your Address',
                textInputType: TextInputType.text,
                prefixIcon: const Icon(Icons.location_pin, color: Colors.pink),
                onChanged: (value) {
                  setState(() {
                    addres = value;
                  });
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please Enter your address';
                  } else {
                    return null;
                  }
                },
              ),
              InputTextfield(
                controller: _zipcodeController,
                hintText: 'Enter Your zipcode',
                textInputType: TextInputType.number,
                prefixIcon: const Icon(Icons.code_rounded, color: Colors.amber),
                onChanged: (value) {
                  setState(() {
                    zipcode = value;
                  });
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please Enter your zipcode';
                  } else {
                    return null;
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SelectState(
                  style: styles(color: Colors.black54),
                  onCountryChanged: (value) {
                    setState(() {
                      countryValue = value;
                    });
                  },
                  onStateChanged: (value) {
                    setState(() {
                      stateValue = value;
                    });
                  },
                  onCityChanged: (value) {
                    setState(() {
                      cityValue = value;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tax Registered?',
                      style: styles(color: Colors.cyan.shade600, fontSize: 16),
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
                          onChanged: (value) {
                            setState(() {
                              _taxStatus = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _taxStatus == 'YES'
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            taxNumber = value;
                          });
                        },
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Please Tax Number must not be empty';
                          } else {
                            return null;
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Tax Number',
                          labelStyle: styles(color: Colors.cyan.shade600),
                        ),
                      ),
                    )
                  : const SizedBox(),

              const SizedBox(height: 70),
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

  // ใหม่: Functions สำหรับ QR Image Picker
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

  // Future<void> selectQRCamera() async {
  //   Uint8List? img = await vendorController.pickStoreImage(ImageSource.camera);
  //   if (img != null) {
  //     setState(() {
  //       qrImage = img;
  //     });
  //   }
  // }

  Future<void> selectQRGallery() async {
    Uint8List? img = await vendorController.pickStoreImage(ImageSource.gallery);
    if (img != null) {
      setState(() {
        qrImage = img;
      });
    }
  }

  selectCameca() async {
    Uint8List img = await vendorController.pickStoreImage(ImageSource.camera);
    setState(() {
      image = img;
    });
  }

  selectGallery() async {
    final img = await vendorController.pickStoreImage(ImageSource.gallery);

    setState(() {
      image = img;
    });
  }

  remove() {
    setState(() {
      image = null; // Clear image
    });
    Navigator.pop(context);
  }
}
