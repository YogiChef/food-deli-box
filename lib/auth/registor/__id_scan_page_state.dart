// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:thai_id_card_numbers/thai_id_card_numbers.dart';
import 'package:vendor_box/services/sevice.dart';

class IdScanPage extends StatefulWidget {
  const IdScanPage({super.key});
  @override
  State<IdScanPage> createState() => _IdScanPageState();
}

class _IdScanPageState extends State<IdScanPage> {
  bool _isScanning = false;
  bool _cameraInitialized = false;
  bool _showPreview = false; // ใหม่: แสดง preview หลัง scan
  String _cameraStatus = 'กำลังเริ่มกล้อง...';
  String _parsedIdNumber = '';
  String _parsedBirthDate = '';
  String _parsedCardOwnerName = '';
  XFile? _scannedImage; // เก็บภาพที่สแกน
  CameraController? _cameraController;
  List<CameraDescription> cameras = [];
  late TextRecognizer _textRecognizer;
  late Future<void> _initializeCameraFuture;
  @override
  void initState() {
    super.initState();
    _initTextRecognizer();
    _initializeCameraFuture = _initCamera();
  }

  void _initTextRecognizer() {
    _textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin, // รองรับไทย (unicode)
    );
  }

  Future<void> _initCamera() async {
    try {
      if (!mounted) return;
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraStatus = 'ไม่พบกล้อง';
          });
          Fluttertoast.showToast(msg: 'ไม่พบกล้อง');
        }
        return;
      }
      // ใช้กล้องหลังสำหรับสแกนบัตร (ชัดกว่า)
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high, // ความละเอียดสูงสำหรับ OCR
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _cameraInitialized = true;
          _cameraStatus = 'วางบัตรในกรอบด้านล่าง';
        });
        print('ID scan camera initialized successfully');
      }
    } catch (e) {
      print('ID scan camera init error: $e');
      if (mounted) {
        setState(() {
          _cameraStatus = 'กล้องล้มเหลว: $e';
        });
        Fluttertoast.showToast(msg: 'ไม่สามารถเปิดกล้องได้: $e');
      }
    }
  }

  // ฟังก์ชัน _parseIdCardData สำหรับ IdScanPage - ใช้ local vars (_parsed...) และ setState _showPreview
  void _parseIdCardData(String recognizedText) {
    try {
      // ล้างข้อมูลเก่า
      _parsedIdNumber = '';
      _parsedBirthDate = '';
      _parsedCardOwnerName = '';
      if (recognizedText.isEmpty) {
        _showPreview = false;
        setState(() {
          _cameraStatus = 'OCR ไม่พบข้อความ ลองสแกนใหม่';
        });
        Fluttertoast.showToast(msg: 'OCR ไม่พบข้อความ ลองสแกนชัดๆ ในที่สว่าง');
        return;
      }
      String text = recognizedText.replaceAll(RegExp(r'\s+'), ' ');
      print('Cleaned TEXT: $text');

      // หาเลขบัตร (เดิม)
      RegExp idRegex = RegExp(r'(\d\s*){13}');
      Match? idMatch = idRegex.firstMatch(text);
      if (idMatch != null) {
        _parsedIdNumber = idMatch.group(0)!.replaceAll(RegExp(r'\s'), '');
        if (_parsedIdNumber.length == 13) {
          final thaiIdValidator = ThaiIdCardNumbers();
          if (!thaiIdValidator.validate(_parsedIdNumber)) {
            _parsedIdNumber = '';
          }
        } else {
          _parsedIdNumber = '';
        }
      }
      print('Parsed ID: $_parsedIdNumber');

      // หา First Name (loose: handle "Neme" / "Nane" as "Name")
      String firstName = '';
      RegExp firstRegex = RegExp(
        r'(?:Name|Neme|Nane)[\s:]*Mr\.\s*([A-Za-z\u0E00-\u0E7F]+?)(?=\s*(?:Last|นามสกุล|เลขบัตร|\d|$))',
      );
      Match? firstMatch = firstRegex.firstMatch(text);
      if (firstMatch != null) {
        firstName = firstMatch.group(1)!.trim();
      }
      print('Parsed First: $firstName');

      // หา Last Name (ปรับ regex ให้ loose กว่า: จับ "Last name", "Last naye" ได้ และ lookahead กว้างขึ้น)
      String lastName = '';
      RegExp lastRegex = RegExp(
        r'Last\s*(?:name|naye|nayme|nane|nanme|nanse)[\s:]*([A-Za-z\u0E00-\u0E7F]+?)(?=\s*(?:Date|Birth|Expiry|เกิด|เลข|\d{1,4}|$))',
      );
      Match? lastMatch = lastRegex.firstMatch(text);
      if (lastMatch != null) {
        lastName = lastMatch.group(1)!.trim();
      }
      print('Parsed Last: $lastName');

      // Concat full name
      _parsedCardOwnerName = firstName.isNotEmpty ? firstName : '';
      if (lastName.isNotEmpty) {
        _parsedCardOwnerName +=
            (_parsedCardOwnerName.isNotEmpty ? ' ' : '') + lastName;
      }
      print('Parsed Full Name: $_parsedCardOwnerName');

      // หาวันเกิด (ปรับ regex ให้ loose กว่า: เพิ่ม variations และ handle comma ในเดือน)
      RegExp birthRegex = RegExp(
        r'(?:Date of Birth|Data of Brth|Deta of Bith|Date of Brth|Data of Brth|Date of Brth)[\s:]*(\d{1,2})\s*([A-Za-z]{3,}[,.]?\s*)?(\d{4})',
      );
      Match? birthMatch = birthRegex.firstMatch(text);
      if (birthMatch != null) {
        String day = birthMatch.group(1)!;
        String month = birthMatch
            .group(2)!
            .replaceAll(RegExp(r'[,.]'), '')
            .trim();
        String year = birthMatch.group(3)!;
        if (year.length == 4 &&
            int.tryParse(year) != null &&
            int.parse(year) > 2500) {
          year = (int.parse(year) - 543).toString();
        }
        _parsedBirthDate = '$day/$month/$year';
        print('Parsed Birth: $_parsedBirthDate');
      }
      print('Parsed Birth: $_parsedBirthDate');

      // ถ้าข้อมูลครบ แสดง preview
      if (mounted) {
        setState(() {
          _showPreview = true;
        });
        bool isComplete =
            _parsedIdNumber.isNotEmpty &&
            _parsedCardOwnerName.isNotEmpty &&
            _parsedBirthDate.isNotEmpty;
        String successMsg = 'สแกนสำเร็จ! ';
        if (_parsedIdNumber.isNotEmpty)
          successMsg += 'เลขบัตร: $_parsedIdNumber ';
        if (_parsedCardOwnerName.isNotEmpty)
          successMsg += 'ชื่อ: $_parsedCardOwnerName ';
        if (_parsedBirthDate.isNotEmpty)
          successMsg += 'วันเกิด: $_parsedBirthDate';
        if (isComplete) {
          Fluttertoast.showToast(msg: '$successMsg (ครบถ้วน!)');
        } else {
          Fluttertoast.showToast(msg: '$successMsg (ไม่ครบ สแกนใหม่)');
        }
      }
    } catch (e) {
      print('Parse Error: $e');
      setState(() {
        _showPreview = false;
        _cameraStatus = 'Parse ล้มเหลว ลองสแกนใหม่';
      });
      Fluttertoast.showToast(msg: 'Parse ข้อมูลล้มเหลว ลองสแกนใหม่');
    }
  }

  Future<void> _scanIdCard() async {
    print('เริ่มสแกนบัตรประชาชน');
    if (!_cameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      Fluttertoast.showToast(msg: 'กล้องไม่พร้อม ลองใหม่');
      await _initCamera();
      if (!_cameraInitialized) return;
    }
    if (!mounted) return;
    setState(() => _isScanning = true);
    try {
      _scannedImage = await _cameraController!.takePicture();
      print('สแกนบัตรสำเร็จ - path: ${_scannedImage!.path}');
      final inputImage = InputImage.fromFilePath(_scannedImage!.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      String fullText = '';
      for (TextBlock block in recognizedText.blocks) {
        fullText += '${block.text}\n';
      }
      print('RAW OCR TEXT: $fullText');
      _parseIdCardData(fullText);
    } catch (e) {
      print('ID scan error: $e');
      setState(() {
        _cameraStatus = 'สแกนล้มเหลว: $e';
      });
      Fluttertoast.showToast(msg: 'สแกนบัตรล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _rescan() {
    setState(() {
      _showPreview = false;
      _parsedIdNumber = '';
      _parsedBirthDate = '';
      _parsedCardOwnerName = '';
      _scannedImage = null;
      _cameraStatus = 'วางบัตรในกรอบด้านล่าง';
    });
  }

  void _confirmScan() {
    bool isComplete =
        _parsedIdNumber.isNotEmpty &&
        _parsedCardOwnerName.isNotEmpty &&
        _parsedBirthDate.isNotEmpty;
    if (_scannedImage != null && isComplete) {
      Navigator.pop(context, {
        'path': _scannedImage!.path,
        'idNumber': _parsedIdNumber,
        'birthDate': _parsedBirthDate,
        'cardOwnerName': _parsedCardOwnerName,
      });
    } else {
      Fluttertoast.showToast(
        msg: 'ข้อมูลไม่ครบ (ID/ชื่อ/วันเกิด) กรุณาสแกนใหม่',
      );
    }
  }

  @override
  void dispose() {
    try {
      _cameraController?.dispose();
    } catch (e) {
      print('ID scan camera dispose error: $e');
    }
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สแกนบัตรประชาชน'),
        backgroundColor: Colors.cyan.shade400,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (!_showPreview) ...[
            FutureBuilder<void>(
              future: _initializeCameraFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError ||
                    !_cameraInitialized ||
                    _cameraController == null ||
                    !_cameraController!.value.isInitialized) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.credit_card,
                          size: 100,
                          color: Colors.grey,
                        ),
                        Text(
                          _cameraStatus,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        ElevatedButton(
                          onPressed: _initCamera,
                          child: const Text('ลองเริ่มกล้องใหม่'),
                        ),
                      ],
                    ),
                  );
                }
                return Stack(
                  children: [
                    CameraPreview(_cameraController!),
                    // Guide frame for ID card (เลื่อนลงต่ำกว่า: top 0.3 = 30% จากบน เพื่อให้สแกนยกกล้องต่ำๆ)
                    Positioned(
                      top: height * 0.2, // ปรับจาก 0.15 เป็น 0.3 เพื่อกรอบต่ำลง
                      left: 12.w,
                      right: 12.w,
                      child: Container(
                        height: 240.h, // ขนาดกรอบสำหรับบัตร
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.green.shade400,
                            width: 3,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Center(
                            child: Text(
                              'วางบัตรที่นี่ (ต่ำลง)',
                              style: TextStyle(
                                color: Colors.green.shade400,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_isScanning)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ] else ...[
            // Preview mode หลัง scan
            Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(_scannedImage!.path),
                        fit: BoxFit.contain,
                      ),
                      Positioned(
                        bottom: 120.h,
                        left: 12.w,
                        right: 12.w,
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ข้อมูลที่สแกนได้:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'เลขบัตร: ${_parsedIdNumber.isEmpty ? 'ไม่พบ' : _parsedIdNumber}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'ชื่อ: ${_parsedCardOwnerName.isEmpty ? 'ไม่พบ' : _parsedCardOwnerName}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'วันเกิด: ${_parsedBirthDate.isEmpty ? 'ไม่พบ' : _parsedBirthDate}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          // Bottom buttons
          Positioned(
            bottom: 20.h,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _showPreview
                    ? ElevatedButton.icon(
                        onPressed: _rescan,
                        icon: const Icon(Icons.refresh),
                        label: const Text('สแกนใหม่'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      )
                    : FloatingActionButton.extended(
                        onPressed: _isScanning || _showPreview
                            ? null
                            : _scanIdCard,
                        icon: _isScanning
                            ? SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.camera_alt, color: Colors.white),
                        label: Text(_isScanning ? 'กำลังสแกน...' : 'สแกนบัตร'),
                        backgroundColor: Colors.cyan.shade400,
                      ),
                _showPreview
                    ? ElevatedButton.icon(
                        onPressed: _confirmScan,
                        icon: const Icon(Icons.check),
                        label: const Text('ยืนยัน'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
          // Status text (ปรับ top ต่ำลงเป็น 150.h เพื่อให้ align กับกรอบใหม่)
          Positioned(
            top: height * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _cameraStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
