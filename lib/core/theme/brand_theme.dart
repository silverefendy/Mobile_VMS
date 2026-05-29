import 'package:flutter/material.dart';

class BrandTheme {
  const BrandTheme({required this.appName, required this.seedColor, this.logoUrl});
  final String appName;
  final Color seedColor;
  final String? logoUrl;

  static const fallback = BrandTheme(appName: 'VMS', seedColor: Colors.indigo);
}
