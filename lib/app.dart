import 'package:flutter/material.dart';
import 'screens/login/login_screen.dart';

class MobileVMSApp extends StatelessWidget {
  const MobileVMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile VMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
