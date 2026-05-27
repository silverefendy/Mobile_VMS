import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Operational Settings')),
      body: ListView(
        children: [
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
