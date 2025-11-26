// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vendor_box/services/sevice.dart'; // สำหรับ styles()

class TimeSelectorWidget extends StatefulWidget {
  final String dayLabel;
  final Function(String day, String? open, String? close) onSave;
  final Function(bool)? onClosed; // ถ้าต้องการ
  final String? currentOpen;
  final String? currentClose;
  final bool currentClosed;

  const TimeSelectorWidget({
    super.key,
    required this.dayLabel,
    required this.onSave,
    this.currentOpen,
    this.currentClose,
    this.onClosed,
    this.currentClosed = false,
  });

  @override
  State<TimeSelectorWidget> createState() => _TimeSelectorWidgetState();
}

class _TimeSelectorWidgetState extends State<TimeSelectorWidget> {
  bool isClosed = false;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  @override
  void initState() {
    super.initState();
    isClosed = widget.currentClosed;
    _openTime = widget.currentOpen != null
        ? _parseTime(widget.currentOpen!)
        : null;
    _closeTime = widget.currentClose != null
        ? _parseTime(widget.currentClose!)
        : null;
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
        : (widget.currentOpen ?? 'เปิด');
    final closeText = _closeTime != null
        ? _closeTime!.format(context)
        : (widget.currentClose ?? 'ปิด');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      child: Padding(
        padding: EdgeInsets.only(
          top: 6.h,
          bottom: 6.h,
          left: 12.w,
          right: 12.w,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.dayLabel,
                  style: styles(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: mainColor,
                  ),
                ),
                const Spacer(),
                Transform.scale(
                  scale: 0.75.r,
                  child: Switch(
                    padding: EdgeInsets.all(2.w),
                    value: !isClosed, // true = เปิด (switch on)
                    onChanged: (value) {
                      setState(() {
                        isClosed = !value; // value=true=เปิด -> _isClosed=false
                      });
                      widget.onClosed?.call(isClosed); // Call parent
                      if (isClosed) {
                        _openTime = null;
                        _closeTime = null;
                      }
                    },
                    activeThumbColor: mainColor, // สีเมื่อเปิด
                    activeTrackColor: mainColor.withAlpha(50),
                    inactiveThumbColor: Colors.red, // สีเมื่อปิด
                    inactiveTrackColor: Colors.red.withAlpha(50),
                    trackOutlineColor: WidgetStateProperty.all(Colors.grey),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(left: 24.w),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(true),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13.sp,
                            color: Colors.black87,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            openText,
                            style: styles(
                              fontSize: 14.sp,
                              fontWeight: _openTime != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(false),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13.sp,
                            color: Colors.red.shade700,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            closeText,
                            style: styles(
                              fontSize: 14.sp,
                              fontWeight: _closeTime != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_openTime != null || _closeTime != null) ...[
              Padding(
                padding: EdgeInsets.only(left: 24.w),
                child: Text(
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
