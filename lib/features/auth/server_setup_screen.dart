import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/server_config/connection_service.dart';
import '../../core/server_config/server_config_service.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isTesting = false;
  bool _testSuccess = false;
  String? _testMessage;
  String? _errorDetails;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testSuccess = false;
      _testMessage = null;
      _errorDetails = null;
    });

    final serverConfig = context.read<ServerConfigService>();
    final connectionService = ConnectionService();

    final valid = await serverConfig.setServerUrl(_urlController.text.trim());
    if (!valid) {
      setState(() {
        _isTesting = false;
        _testMessage = serverConfig.errorMessage;
      });
      return;
    }

    final result = await connectionService.testConnectionDetailed(
      serverConfig.serverUrl!,
    );

    setState(() {
      _isTesting = false;
      _testSuccess = result.success;
      _testMessage = result.message;
      _errorDetails = result.errorDetails;
    });

    if (result.success) {
      serverConfig.setStatus(ServerConfigStatus.valid);
    } else {
      serverConfig.setStatus(
        ServerConfigStatus.invalid,
        errorMessage: result.message,
      );
    }
  }

  void _showErrorDetails() {
    if (_errorDetails == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Error'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorDetails!,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Tips:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('\u2022 Pastikan URL benar dan server aktif'),
              const Text('\u2022 Untuk HTTP lokal, gunakan format http://IP:port'),
              const Text('\u2022 Untuk HTTPS, pastikan sertifikat valid'),
              const Text('\u2022 Visitor Management API harus terinstall'),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _errorDetails!));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error details copied')));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final serverConfig = context.read<ServerConfigService>();
    if (serverConfig.status != ServerConfigStatus.valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test koneksi dulu sebelum menyimpan')),
      );
      return;
    }

    // Simpan ke SharedPreferences
    await serverConfig.saveServerUrl();

    // *** KRITIS: Update AppConfig dan ApiClient dengan URL baru ***
    // Tanpa ini, ApiClient masih pakai baseUrl lama/kosong saat login
    final newUrl = serverConfig.serverUrl!;
    AppConfig.baseUrl = newUrl;
    if (mounted) {
      context.read<ApiClient>().updateBaseUrl(newUrl);
    }

    // Router akan redirect otomatis ke /login karena
    // ServerConfigService.isConfigured sekarang true
    // Tidak perlu Navigator manual
  }

  @override
  Widget build(BuildContext context) {
    final serverConfig = context.watch<ServerConfigService>();
    final canSave = serverConfig.status == ServerConfigStatus.valid;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: kBrandTeal,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                                color: kBrandTeal.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: const Icon(Icons.domain_rounded,
                            size: 46, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text('VMS',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: kBrandTeal,
                              letterSpacing: 2)),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Masukkan URL server ERPNext Anda',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // URL field
                    TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'http://10.1.0.30:8001',
                        prefixIcon: const Icon(Icons.link_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: kBrandTeal, width: 1.8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Server URL tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Test result
                    if (_testMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _testSuccess
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _testSuccess
                                  ? Colors.green.shade200
                                  : Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _testSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              color: _testSuccess ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_testMessage!,
                                  style: TextStyle(
                                      color: _testSuccess
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                      fontSize: 13)),
                            ),
                            if (!_testSuccess && _errorDetails != null)
                              IconButton(
                                icon: const Icon(Icons.info_outline,
                                    size: 18, color: Color(0xFF64748B)),
                                onPressed: _showErrorDetails,
                                tooltip: 'Lihat detail error',
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Test button
                    OutlinedButton(
                      onPressed: _isTesting ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kBrandTeal,
                        side: const BorderSide(color: kBrandTeal),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isTesting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: kBrandTeal))
                          : const Text('Test Koneksi',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),

                    // Save button
                    FilledButton(
                      onPressed: canSave ? _save : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: kBrandTeal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Simpan & Lanjutkan',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
