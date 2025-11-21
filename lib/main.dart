import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:vendor_box/auth/landing_page.dart'; // Import LandingPage
import 'package:vendor_box/providers/product_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Global error handling to avoid white screen
  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter error: ${details.exception}');
  };
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      Scaffold(body: Center(child: Text('App Error: ${details.exception}')));

  // Init Firebase แบบ safe
  try {
    if (Firebase.apps.isEmpty) {
      if (Platform.isAndroid) {
        await Firebase.initializeApp(
          name: 'vendor_app',
          options: const FirebaseOptions(
            apiKey: 'AIzaSyB8fTtl61cv2giyA9xx124fTS-1bjpDSmU',
            appId: '1:613403315885:android:98be491eceef3021ad0024',
            messagingSenderId: '613403315885',
            projectId: 'deli-box',
            storageBucket: 'deli-box.appspot.com', // แก้ format
          ),
        );
      } else {
        await Firebase.initializeApp(
          name: 'vendor_app',
          options: const FirebaseOptions(
            apiKey: 'AIzaSyB8fTtl61cv2giyA9xx124fTS-1bjpDSmU',
            appId: '1:613403315885:ios:YOUR_VENDOR_IOS_ID', // จาก console
            messagingSenderId: '613403315885',
            projectId: 'deli-box',
            iosBundleId: 'com.example.vendorBox',
          ),
        );
      }
      print('Firebase initialized for vendor_app');
    } else {
      print('Firebase already initialized (skipping)');
    }
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      print('Duplicate app – skipping init');
    } else {
      print('Firebase init error: $e');
    }
  } catch (e) {
    print('Unexpected Firebase error: $e');
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ProductProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.dark,
      ),
    );
    return ScreenUtilInit(
      designSize: const Size(375, 815),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Vendor Box', // เปลี่ยนให้ match
          theme: ThemeData(
            scaffoldBackgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black26),
            primarySwatch: Colors.blue,
            textTheme: Typography.englishLike2018.apply(
              fontSizeFactor: 1.sp,
              bodyColor: Colors.black,
            ),
          ),
          home:
              const LandingPage(), // const LandingPage – ใช้ const constructor
          builder: EasyLoading.init(),
        );
      },
    );
  }
}
