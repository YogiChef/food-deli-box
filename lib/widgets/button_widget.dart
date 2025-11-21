import 'package:flutter/material.dart';

class BottonWidget extends StatelessWidget {
  final String label;
  final IconData icon;
  final Function() press;
  final TextStyle? style;
  final Color? color;
  final double? size;
  final double? height;

  const BottonWidget({
    super.key,
    required this.label,
    required this.icon,
    this.style,
    required this.press,
    this.color,
    this.size,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          maximumSize: MediaQuery.of(context).size,
          backgroundColor: color ?? Colors.pink.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        label: Text(label, style: style),
        onPressed: press,
        icon: Icon(icon, size: size ?? 24, color: Colors.white),
      ),
    );
  }
}
