// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:vendor_box/auth/landing_page.dart';
import 'package:vendor_box/providers/product_provider.dart';

// ถ้ามี firebase_options.dart จาก flutterfire configure ให้ import
// import 'firebase_options.dart';

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

  // Init Firebase แบบ safe – ใช้ default app (ไม่มี name) เพื่อให้ plugins ใช้ Firebase.app() ได้
  try {
    if (Firebase.apps.isEmpty) {
      // ถ้ามี firebase_options.dart: await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      // ถ้าไม่มี: ใช้ options manual (แนะนำรัน flutterfire configure เพื่อ generate)
      if (Platform.isAndroid) {
        await Firebase.initializeApp(
          // ลบ name: 'vendor_app' เพื่อเป็น default
          options: const FirebaseOptions(
            apiKey: 'AIzaSyB8fTtl61cv2giyA9xx124fTS-1bjpDSmU',
            appId: '1:613403315885:android:98be491eceef3021ad0024',
            messagingSenderId: '613403315885',
            projectId: 'deli-box',
            storageBucket: 'deli-box.appspot.com',
          ),
        );
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug, // สำหรับ Android debug builds
          appleProvider: AppleProvider.debug, // สำหรับ iOS debug (ถ้าต้องการ)
        );
      } else {
        await Firebase.initializeApp(
          // ลบ name: 'vendor_app'
          options: const FirebaseOptions(
            apiKey: 'AIzaSyB8fTtl61cv2giyA9xx124fTS-1bjpDSmU',
            appId:
                '1:613403315885:ios:98be491eceef3021ad0024', // แก้จาก 'YOUR_VENDOR_IOS_ID' – เช็คใน Firebase Console > Project Settings > iOS app > App ID
            messagingSenderId: '613403315885',
            projectId: 'deli-box',
            iosBundleId:
                'com.dev.box_vendor', // เปลี่ยนจาก 'com.example.vendorBox' ให้ตรงกับ AndroidManifest.xml
          ),
        );
      }
      print('Firebase initialized (default app)');
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

  // Offload runApp to next frame เพื่อลด main thread load (แก้ skipped frames)
  await Future.delayed(Duration.zero);

  runApp(
    MultiProvider(
      providers: [
        // ย้าย init provider ไป lazy: ใช้ create: (_) => ProductProvider() แต่ถ้า init หนัก ให้ใช้ ChangeNotifierProxyProvider ถ้าจำเป็น
        ChangeNotifierProvider(create: (_) => ProductProvider()),
      ],
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
          title: 'Vendor Box',
          theme: ThemeData(
            scaffoldBackgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black26),
            primarySwatch: Colors.blue,
            textTheme: Typography.englishLike2018.apply(
              fontSizeFactor: 1.sp,
              bodyColor: Colors.black,
            ),
          ),
          darkTheme: ThemeData(
            // FIXED: Dark theme - Text สว่าง
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.grey, // Background ดำสนิท
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white), // Text สีขาวสว่าง
              bodyMedium: TextStyle(
                color: Colors.white70,
              ), // หรือ white70 สำหรับ contrast
              headlineSmall: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black, // AppBar ดำ
              foregroundColor: Colors.white, // Text ใน AppBar สว่าง
            ),
          ),
          themeMode: ThemeMode.system,
          home: const LandingPage(),
          builder: EasyLoading.init(),
        );
      },
    );
  }
}
