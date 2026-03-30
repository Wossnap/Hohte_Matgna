import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.red,
      body: Center(
        child: Text(
          'DEBUG MODE: App Started',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    ),
  ));
}
