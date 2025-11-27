// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_box/auth/landing_page.dart';
import 'package:vendor_box/auth/vendor_registor_page.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/widgets/button_widget.dart';
import 'package:vendor_box/widgets/input_textfield.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // ignore: unused_field
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  CollectionReference buyers = firestore.collection('buyers');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late String email;
  late String password;
  bool _obscureText = true;
  bool _isLoading = false;

  login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await vendorController.loginUser(email, password);
        await auth.currentUser!.reload();
        _formKey.currentState!.reset();
        print('Login success – Going to LandingPage'); // Debug
        // Navigate ไป LandingPage (แทน Get.to)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LandingPage()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        String msg = e.code == 'user-not-found'
            ? 'ไม่พบผู้ใช้'
            : 'กรุณากรอกข้อมูลให้ถูกต้อง';
        Fluttertoast.showToast(msg: msg);
      } catch (e) {
        setState(() => _isLoading = false);
        print('Login error: $e'); // Debug
        Fluttertoast.showToast(msg: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
        behavior: HitTestBehavior.opaque,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 170,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('images/viewcover.webp'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 12,
                      child: Text(
                        'Login\nVendor\'s Account',
                        textAlign: TextAlign.left,
                        style: styles(
                          fontSize: 16,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.yellow.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                InputTextfield(
                  onChanged: (value) {
                    setState(() {
                      email = value;
                    });
                  },
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please enter your email address';
                    } else if (value.isValidEmail() == false) {
                      return 'invalid email';
                    } else {
                      return null;
                    }
                  },
                  hintText: 'Enter Email',
                  textInputType: TextInputType.emailAddress,
                  prefixIcon: Icon(Icons.email, color: Colors.cyan.shade400),
                ),
                InputTextfield(
                  hintText: 'Enter Password',
                  textInputType: TextInputType.text,
                  prefixIcon: Icon(Icons.lock, color: Colors.red.shade600),
                  obscureText: _obscureText,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText == true
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                  onChanged: (value) {
                    setState(() {
                      password = value;
                    });
                  },
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please enter your password';
                    } else if (value.length < 8) {
                      return 'Passwords longer than eight characters';
                    } else {
                      return null;
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Colors.yellow.shade900,
                            ),
                          )
                        : BottonWidget(
                            label: 'Login',
                            style: styles(
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: null,
                            ),
                            icon: Icons.login,
                            press: login,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Need an account',
                        style: GoogleFonts.righteous(fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VendorRegistorPage(),
                            ),
                          );
                        },
                        child: Text(
                          'SignUp',
                          style: GoogleFonts.righteous(
                            color: Colors.cyan.shade400,
                            letterSpacing: 1,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
