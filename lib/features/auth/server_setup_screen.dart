import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

    // Set and validate URL first
    final valid = await serverConfig.setServerUrl(_urlController.text.trim());
    if (!valid) {
      setState(() {
        _isTesting = false;
        _testMessage = serverConfig.errorMessage;
      });
      return;
    }

    // Use detailed connection test for better error reporting
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

  /// Show detailed error dialog when connection fails
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
              Text(
                _errorDetails!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Pastikan URL benar dan server aktif'),
              const Text('• Untuk HTTP lokal, gunakan format http://IP:port'),
              const Text('• Untuk HTTPS, pastikan sertifikat valid'),
              const Text('• Visitor Management API harus terinstall'),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _errorDetails!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error details copied')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final serverConfig = context.read<ServerConfigService>();
    if (serverConfig.status != ServerConfigStatus.valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please test connection before saving')),
      );
      return;
    }

    await serverConfig.saveServerUrl();
    if (mounted) {
      // Navigate to login - router will handle the redirect
      // based on serverConfig.isConfigured and auth status
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverConfig = context.watch<ServerConfigService>();
    final canSave = serverConfig.status == ServerConfigStatus.valid;

    return Scaffold(
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
                    const Icon(
                      Icons.settings_rounded,
                      size: 64,
                      color: Color(0xFF0F2A5F),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to VMS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F2A5F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please configure your server URL to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'https://your-server.com',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Server URL is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_testMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _testSuccess
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _testSuccess
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _testSuccess
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color:
                                      _testSuccess ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _testMessage!,
                                    style: TextStyle(
                                      color: _testSuccess
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                                if (!_testSuccess && _errorDetails != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Color(0xFF64748B),
                                    ),
                                    onPressed: _showErrorDetails,
                                    tooltip: 'Show error details',
                                  ),
                              ],
                            ),
                            if (!_testSuccess) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Tap info icon for details',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: _isTesting ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isTesting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test Connection'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: canSave ? _save : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Save & Continue'),
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
