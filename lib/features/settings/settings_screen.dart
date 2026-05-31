import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/server_config/connection_service.dart';
import '../../core/server_config/server_config_service.dart';
import '../../core/settings/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _ServerConfigSection(),
          const Divider(),
          SwitchListTile(
            title: const Text('Scan sound feedback'),
            value: settings.scanSoundEnabled,
            onChanged: settings.setScanSound,
          ),
          SwitchListTile(
            title: const Text('Scan vibration feedback'),
            value: settings.scanVibrationEnabled,
            onChanged: settings.setScanVibration,
          ),
          ListTile(
            title: const Text('Theme mode'),
            subtitle: Text(settings.themeMode.name),
            trailing: DropdownButton<AppThemeMode>(
              value: settings.themeMode,
              onChanged: (v) => v != null ? settings.setThemeMode(v) : null,
              items: const [
                DropdownMenuItem(value: AppThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: AppThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: AppThemeMode.dark, child: Text('Dark')),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _ServerConfigSection extends StatefulWidget {
  const _ServerConfigSection();

  @override
  State<_ServerConfigSection> createState() => _ServerConfigSectionState();
}

class _ServerConfigSectionState extends State<_ServerConfigSection> {
  bool _isEditing = false;
  bool _isTesting = false;
  bool? _testResult;
  String? _testMessage;
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    final serverConfig = context.read<ServerConfigService>();
    _urlController = TextEditingController(text: serverConfig.serverUrl ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (_urlController.text.trim().isEmpty) {
      setState(() {
        _testResult = false;
        _testMessage = 'URL cannot be empty';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testMessage = null;
    });

    final serverConfig = context.read<ServerConfigService>();
    final connectionService = ConnectionService();

    await serverConfig.setServerUrl(_urlController.text.trim());
    if (serverConfig.serverUrl == null) {
      setState(() {
        _isTesting = false;
        _testResult = false;
        _testMessage = serverConfig.errorMessage ?? 'Invalid URL';
      });
      return;
    }

    final success = await connectionService.testConnection(serverConfig.serverUrl!);
    setState(() {
      _isTesting = false;
      _testResult = success;
      _testMessage = success ? 'Connection Success' : 'Unable to connect';
    });

    if (success) {
      serverConfig.setStatus(ServerConfigStatus.valid);
    } else {
      serverConfig.setStatus(ServerConfigStatus.invalid, errorMessage: 'Connection failed');
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
    setState(() => _isEditing = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server configuration saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverConfig = context.watch<ServerConfigService>();

    if (_isEditing) {
      return ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('Server Configuration'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://your-server.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                if (_testMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _testResult == true 
                          ? Colors.green.shade50 
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _testMessage!,
                      style: TextStyle(
                        color: _testResult == true 
                            ? Colors.green.shade700 
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _isTesting ? null : _testConnection,
                      child: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: serverConfig.status == ServerConfigStatus.valid ? _save : null,
                      child: const Text('Save'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListTile(
      leading: const Icon(Icons.dns),
      title: const Text('Server Configuration'),
      subtitle: Text(serverConfig.serverUrl ?? 'Not configured'),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => setState(() => _isEditing = true),
      ),
    );
  }
}
