import 'package:flutter/material.dart';
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

    final success = await connectionService.testConnection(serverConfig.serverUrl!);

    if (success) {
      serverConfig.setStatus(ServerConfigStatus.valid);
      setState(() {
        _isTesting = false;
        _testSuccess = true;
        _testMessage = 'Connection Success';
      });
    } else {
      serverConfig.setStatus(ServerConfigStatus.invalid, 
        errorMessage: 'Unable to connect to server');
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testMessage = 'Unable to connect';
      });
    }
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
      Navigator.of(context).pushReplacementNamed('/splash');
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
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _testSuccess ? Icons.check_circle : Icons.error,
                              color: _testSuccess ? Colors.green : Colors.red,
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
