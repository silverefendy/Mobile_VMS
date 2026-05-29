import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BrandShield(size: 88),
                const SizedBox(height: 24),
                Text(
                  'VMS',
                  style: textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF0F2A5F),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Visitor Management System',
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
                const SizedBox(height: 16),
                Text(
                  auth.restoring
                      ? 'Memulihkan sesi aman...'
                      : 'Menyiapkan aplikasi...',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandShield extends StatelessWidget {
  const _BrandShield({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0F2A5F),
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F2A5F),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_rounded, color: Colors.white, size: size * 0.62),
          Positioned(
            bottom: size * 0.23,
            child: Icon(
              Icons.badge_outlined,
              color: const Color(0xFF0F2A5F),
              size: size * 0.27,
            ),
          ),
        ],
      ),
    );
  }
}
