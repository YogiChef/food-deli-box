import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vendor_box/auth/vendor_auth.dart';
import 'package:vendor_box/services/sevice.dart';
import 'package:vendor_box/widgets/button_widget.dart';
import 'package:vendor_box/widgets/dialog.dart';

class LogOutPage extends StatefulWidget {
  const LogOutPage({super.key});

  @override
  State<LogOutPage> createState() => _LogOutPageState();
}

class _LogOutPageState extends State<LogOutPage> {
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 40, bottom: 30),
            child: Text(
              'Sign Out',
              style: GoogleFonts.righteous(fontSize: 30, color: Colors.red),
            ),
          ),
          CircleAvatar(
            radius: 120.r,
            backgroundImage: AssetImage('images/signout.png'),
          ),
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 50),
            width: size.width * 0.8,
            child: BottonWidget(
              label: 'Sign Out',
              style: styles(color: Colors.white, fontSize: 20.sp),
              icon: Icons.logout,
              size: 24.sp,
              press: () async {
                MyAlertDialog.showMyDialog(
                  img: const AssetImage('images/signout.png'),
                  contant: 'Are you sure to log out ',
                  context: context,
                  tabNo: () {
                    Navigator.pop(context);
                  },
                  tabYes: () async {
                    await auth.signOut().whenComplete(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VendorAuthPage(),
                        ),
                      ),
                    );

                    await Future.delayed(const Duration(microseconds: 100));
                  },
                  title: 'Log Out',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
