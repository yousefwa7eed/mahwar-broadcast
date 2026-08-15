import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login as $role')),
      body: Center(
        child: Text('Login Screen for $role'),
      ),
    );
  }
}
