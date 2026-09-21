import 'package:flutter/material.dart';

class SplashVersionWidget extends StatelessWidget {
  final String versionText;
  const SplashVersionWidget({super.key, this.versionText = 'v1.0.0'});

  @override
  Widget build(BuildContext context) {
    return Text(
      versionText,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade600,
        letterSpacing: 0.8,
      ),
    );
  }
}
