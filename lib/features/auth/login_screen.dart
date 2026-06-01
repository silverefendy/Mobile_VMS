import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../config/app_config.dart';
import '../../core/auth/auth_controller.dart';
import '../widgets/connection_indicator.dart';
import '../../theme/colors.dart';

const _kLastUsername = 'vms_last_username';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _passwordFocus = FocusNode();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
    
    // ✅ PROACTIVE CHECK: Jika baseUrl kosong saat login terbuka, redirect ke setup
    // This prevents users from seeing login screen with invalid/unconfigured server
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppConfig.baseUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Server URL belum terkonfigurasi'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        // Redirect back to server setup
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/setup');
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kLastUsername);
      if (saved != null && saved.isNotEmpty && mounted) {
        _usernameController.text = saved;
        _passwordFocus.requestFocus();
      }
    } catch (_) {}
  }

  Future<void> _saveUsername(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastUsername, username.trim());
    } catch (_) {}
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    
    // ✅ VALIDASI: Pastikan baseUrl sudah ter-set sebelum login
    if (AppConfig.baseUrl.isEmpty) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Server URL belum terkonfigurasi'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      // Redirect back to server setup if baseUrl is empty
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/setup');
        }
      });
      return;
    }
    
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final auth = context.read<AuthController>();
    
    final ok = await auth.login(username, password);
    
    if (!mounted) return;
    if (ok) {
      await _saveUsername(username);
      // Redirect ke dashboard
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } else {
      setState(() {
        _submitting = false;
        _errorMessage = _friendlyError(auth.error);
      });
    }
  }

  String _friendlyError(String? raw) {
    if (raw == null) return 'Login gagal. Coba lagi.';
    final lower = raw.toLowerCase();
    if (lower.contains('incorrect') || lower.contains('invalid') ||
        lower.contains('wrong') || lower.contains('salah') ||
        lower.contains('password'))
      return 'Username atau password salah. Periksa kembali.';
    if (lower.contains('timeout') || lower.contains('timed out'))
      return 'Koneksi timeout. Periksa jaringan internet Anda.';
    if (lower.contains('network') || lower.contains('socket') ||
        lower.contains('connection'))
      return 'Tidak dapat terhubung ke server. Periksa jaringan internet.';
    if (lower.contains('500') || lower.contains('server error'))
      return 'Server sedang bermasalah. Coba beberapa saat lagi.';
    if (lower.contains('disabled') || lower.contains('not active'))
      return 'Akun tidak aktif. Hubungi administrator.';
    return raw.length > 120 ? '${raw.substring(0, 120)}...' : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: _BrandLogo()),
                        const SizedBox(height: 20),
                        const Center(
                          child: Text('VMS',
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: kBrandTeal,
                                  letterSpacing: 2)),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text('Visitor Management System',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B))),
                        ),
                        const SizedBox(height: 36),
                        if (_errorMessage != null) ...[
                          _ErrorBanner(message: _errorMessage!),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _usernameController,
                          decoration: _inputDecoration(
                            label: 'Username / Email',
                            icon: Icons.person_outline_rounded,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Username tidak boleh kosong'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration(
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                              tooltip: _obscurePassword
                                  ? 'Tampilkan password'
                                  : 'Sembunyikan password',
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) =>
                              (v == null || v.isEmpty)
                                  ? 'Password tidak boleh kosong'
                                  : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _submitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: kBrandTeal,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white))
                                : const Text('Masuk',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text('Terhubung ke server ERPNext',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ✅ Connection indicator di pojok kanan atas
            Positioned(
              top: 8,
              right: 8,
              child: ConnectionIndicator(showText: true),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon:
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: kBrandTeal, width: 1.8)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: kBrandTeal,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: kBrandTeal.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: const Icon(Icons.domain_rounded, size: 48, color: Colors.white),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade700,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}