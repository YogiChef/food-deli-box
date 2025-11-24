// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/services/sevice.dart'; // สำหรับ styles()

class TimeSelectorWidget extends StatefulWidget {
  final String dayLabel;
  final Function(String day, String? open, String? close) onSave;
  final String? currentOpen;
  final String? currentClose;

  const TimeSelectorWidget({
    super.key,
    required this.dayLabel,
    required this.onSave,
    this.currentOpen,
    this.currentClose,
  });

  @override
  State<TimeSelectorWidget> createState() => _TimeSelectorWidgetState();
}

class _TimeSelectorWidgetState extends State<TimeSelectorWidget> {
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  @override
  void initState() {
    super.initState();
    // Pre-fill if provided
    if (widget.currentOpen != null) {
      _openTime = _parseTime(widget.currentOpen!);
    }
    if (widget.currentClose != null) {
      _closeTime = _parseTime(widget.currentClose!);
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      print('Error parsing time: $timeStr, error: $e');
    }
    return null;
  }

  Future<void> _selectTime(bool isOpen) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpen
          ? (_openTime ?? TimeOfDay.now())
          : (_closeTime ?? TimeOfDay.now()),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            // ... textTheme เดิมของคุณ (bodyMedium, bodyLarge, headlineSmall)
            textTheme: Theme.of(context).textTheme.copyWith(
              bodyMedium: styles(fontSize: 12.sp),
              bodyLarge: styles(fontSize: 14.sp),
              headlineSmall: styles(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            // เพิ่ม TimePickerThemeData เพื่อควบคุมตัวเลขเวลา
            timePickerTheme: TimePickerThemeData(
              hourMinuteTextStyle: styles(
                // ตัวเลขใหญ่ชั่วโมง/นาที (เช่น 08:00)
                fontSize:
                    20.sp, // ปรับขนาดที่นี่ (เช่น 16.sp หรือ 18.sp เพื่อเล็กลง)
                fontWeight: FontWeight.w600,
                color: Colors.black, // สีตัวเลข (optional)
              ),
              dialTextStyle: styles(
                // ตัวเลขรอบนาฬิกา (ถ้าใช้โหมด dial)
                fontSize: 14.sp, // ปรับขนาดเล็กลงถ้าต้องการ
                fontWeight: FontWeight.w500,
              ),
              dayPeriodTextStyle: styles(
                // AM/PM (ถ้าใช้ 12 ชั่วโมง)
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            // DialogThemeData เดิมของคุณ (แต่ contentTextStyle อาจไม่จำเป็นแล้ว)
            dialogTheme: DialogThemeData(
              titleTextStyle: styles(
                fontSize: 16.sp, // ขนาดหัวข้อ "Select Time"
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        // แก้: setState ทันทีเพื่อแสดง local
        if (isOpen) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
      final openStr = _formatTime(_openTime);
      final closeStr = _formatTime(_closeTime);
      widget.onSave(
        widget.dayLabel.toLowerCase(),
        openStr,
        closeStr,
      ); // Call parent
      print(
        'Selected timexxx: $openStr - $closeStr for ${widget.dayLabel}',
      ); // Debug
    }
  }

  String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final openText = _openTime != null
        ? _openTime!.format(context)
        : (widget.currentOpen ?? 'เลือกเวลาเปิด');
    final closeText = _closeTime != null
        ? _closeTime!.format(context)
        : (widget.currentClose ?? 'เลือกเวลาปิด');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.dayLabel,
              style: styles(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: mainColor,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _selectTime(true),
                    icon: const Icon(Icons.access_time, size: 20),
                    label: Text(
                      openText,
                      style: styles(
                        fontSize: 14.sp,
                        fontWeight: _openTime != null
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green.shade700,
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 16.w,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _selectTime(false),
                    icon: const Icon(Icons.access_time, size: 20),
                    label: Text(
                      closeText,
                      style: styles(
                        fontSize: 14.sp,
                        fontWeight: _closeTime != null
                            ? FontWeight.w500
                            : FontWeight.normal,
                        color: Colors.red.shade700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade50,
                      foregroundColor: Colors.orange.shade700,
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 16.w,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // แก้: แสดง partial/full – ถ้าเลือก open เท่านั้นแสดง "เปิด: XX:XX", close เท่านั้น "ปิด: XX:XX", ทั้งคู่ "เวลา: open - close"
            if (_openTime != null || _closeTime != null) ...[
              SizedBox(height: 8.h),
              Text(
                _openTime != null && _closeTime != null
                    ? 'เวลา: ${_formatTime(_openTime)} - ${_formatTime(_closeTime)}'
                    : _openTime != null
                    ? 'เปิด: ${_formatTime(_openTime)}'
                    : 'ปิด: ${_formatTime(_closeTime)}',
                style: styles(
                  fontSize: 12.sp,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
