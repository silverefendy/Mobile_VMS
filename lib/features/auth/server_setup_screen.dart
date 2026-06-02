import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/server_config/connection_service.dart';
import '../../core/server_config/server_config_service.dart';
import '../../theme/colors.dart';

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
  bool? _connectionStatus;

  @override
  void initState() {
    super.initState();
    // ✅ FIX 1: Isi text field dengan URL yang sudah tersimpan sebelumnya
    // Sehingga user tidak perlu ketik ulang saat buka setup screen lagi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final serverConfig = context.read<ServerConfigService>();
      final savedUrl = serverConfig.serverUrl;
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _urlController.text = savedUrl;
        // Tandai sebagai sudah terkonfigurasi agar tombol Save langsung aktif
        setState(() {
          _testSuccess = true;
          _connectionStatus = true;
          _testMessage = 'URL tersimpan dari sesi sebelumnya. Test ulang jika perlu.';
        });
      }
    });
  }

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
      _connectionStatus = null;
    });

    final serverConfig = context.read<ServerConfigService>();
    final connectionService = ConnectionService();

    final valid = await serverConfig.setServerUrl(_urlController.text.trim());
    if (!valid) {
      setState(() {
        _isTesting = false;
        _testMessage = serverConfig.errorMessage;
        _connectionStatus = false;
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
      _connectionStatus = result.success;
    });

    if (result.success) {
      AppConfig.baseUrl = serverConfig.serverUrl!;
      if (mounted) {
        context.read<ApiClient>().updateBaseUrl(serverConfig.serverUrl!);
      }
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
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Tips:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• Pastikan URL benar dan server aktif'),
              const Text(
                  '• Untuk HTTP lokal, gunakan format http://IP:port'),
              const Text(
                  '• Untuk HTTPS, pastikan sertifikat valid'),
              const Text(
                  '• Visitor Management API harus terinstall'),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _errorDetails!));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Error details copied')));
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

    // Jika URL di field sama dengan yang sudah tersimpan dan status configured,
    // langsung lanjutkan tanpa perlu test ulang
    final currentUrl = _urlController.text.trim();
    final savedUrl = serverConfig.serverUrl ?? '';
    final isSameUrl = currentUrl == savedUrl ||
        'http://$currentUrl' == savedUrl ||
        currentUrl == savedUrl.replaceFirst('http://', '');

    if (isSameUrl && serverConfig.isConfigured) {
      // URL tidak berubah — langsung set AppConfig dan lanjutkan
      AppConfig.baseUrl = savedUrl;
      if (mounted) {
        context.read<ApiClient>().updateBaseUrl(savedUrl);
      }
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    // URL baru — harus sudah test dan berhasil
    if (!_testSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Test koneksi harus berhasil terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newUrl = serverConfig.serverUrl!;
    AppConfig.baseUrl = newUrl;
    if (mounted) {
      context.read<ApiClient>().updateBaseUrl(newUrl);
    }

    await serverConfig.saveServerUrl();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverConfig = context.watch<ServerConfigService>();
    // Tombol Save aktif jika: sudah test berhasil ATAU URL tidak berubah dari yang tersimpan
    final canSave = _testSuccess || serverConfig.isConfigured;

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
                                color:
                                    kBrandTeal.withValues(alpha: 0.3),
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
                        'Konfigurasi URL Server ERPNext',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ✅ FIX 2: hintText hanya contoh format, bukan nilai default
                    // Nilai real diisi dari savedUrl di initState
                    TextFormField(
                      controller: _urlController,
                      onChanged: (_) {
                        if (_connectionStatus != null) {
                          setState(() {
                            _connectionStatus = null;
                            _testSuccess = false;
                            _testMessage = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Server URL',
                        // ✅ hintText yang jelas menunjukkan ini hanya CONTOH FORMAT
                        hintText: 'Contoh: http://192.168.1.10:8001',
                        prefixIcon: const Icon(Icons.link_rounded),
                        suffixIcon: _buildConnectionIndicator(),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _connectionStatus == null
                                  ? const Color(0xFFE2E8F0)
                                  : _connectionStatus!
                                      ? Colors.green.shade400
                                      : Colors.red.shade400,
                              width:
                                  _connectionStatus != null ? 2 : 1,
                            )),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: _connectionStatus == true
                                    ? Colors.green
                                    : kBrandTeal,
                                width: 1.8)),
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

                    // Banner status
                    if (_isTesting)
                      _StatusBanner(
                        color: Colors.blue.shade50,
                        borderColor: Colors.blue.shade200,
                        icon: const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.blue),
                        ),
                        text: 'Menguji koneksi ke server...',
                        textColor: Colors.blue.shade700,
                      )
                    else if (_testMessage != null)
                      _StatusBanner(
                        color: _testSuccess
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderColor: _testSuccess
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                        icon: Icon(
                          _testSuccess
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          color: _testSuccess
                              ? Colors.green
                              : Colors.orange,
                          size: 20,
                        ),
                        text: _testMessage!,
                        textColor: _testSuccess
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        trailing:
                            !_testSuccess && _errorDetails != null
                                ? IconButton(
                                    icon: const Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: Color(0xFF64748B)),
                                    onPressed: _showErrorDetails,
                                    tooltip: 'Lihat detail error',
                                  )
                                : null,
                      ),

                    const SizedBox(height: 24),

                    // Tombol Test Koneksi
                    OutlinedButton(
                      onPressed: _isTesting ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kBrandTeal,
                        side: const BorderSide(color: kBrandTeal),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isTesting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kBrandTeal))
                          : const Text('Test Koneksi',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),

                    // Tombol Simpan & Lanjutkan
                    FilledButton(
                      onPressed: canSave ? _save : null,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            canSave ? kBrandTeal : Colors.grey,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Simpan & Lanjutkan',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),

                    // Helper text jika belum bisa save
                    if (!canSave)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Klik "Test Koneksi" dulu untuk memvalidasi URL',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
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

  Widget? _buildConnectionIndicator() {
    if (_isTesting) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: kBrandTeal),
        ),
      );
    }
    if (_connectionStatus == null) return null;
    return Tooltip(
      message: _connectionStatus!
          ? 'Terhubung ke server'
          : 'Tidak dapat terhubung',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                _connectionStatus! ? Colors.green : Colors.red,
            boxShadow: [
              BoxShadow(
                color: (_connectionStatus!
                        ? Colors.green
                        : Colors.red)
                    .withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.text,
    required this.textColor,
    this.trailing,
  });

  final Color color;
  final Color borderColor;
  final Widget icon;
  final String text;
  final Color textColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(color: textColor, fontSize: 13)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
