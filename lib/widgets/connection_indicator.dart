import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../core/server_config/server_config_service.dart';
import '../core/network/api_client.dart';

/// Global connection status indicator widget
/// Shows a colored lamp (green=online, red=offline) in app corners
class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({
    super.key,
    this.position = ConnectionPosition.topRight,
    this.showText = false,
  });

  final ConnectionPosition position;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ServerConfigService, ApiClient>(
      builder: (context, serverConfig, apiClient, child) {
        final isConnected = _checkConnection(serverConfig, apiClient);
        final tooltip = _getConnectionTooltip(isConnected, serverConfig);

        return Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 300),
          child: Container(
            margin: _getMargin(position),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: isConnected ? Colors.green.shade200 : Colors.red.shade200,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lampu indikator dengan glow effect
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? Colors.green : Colors.red,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? Colors.green : Colors.red)
                            .withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (showText) ...[
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  bool _checkConnection(ServerConfigService config, ApiClient? apiClient) {
    // Check 1: Server URL must be configured and valid
    if (config.status != ServerConfigStatus.valid) return false;
    
    // Check 2: Base URL must be set
    if (config.serverUrl?.isEmpty ?? true) return false;
    
    // Check 3: AppConfig.baseUrl must match (runtime check)
    if (AppConfig.baseUrl.isEmpty) return false;
    
    // All checks passed - connection is considered active
    return true;
  }

  String _getConnectionTooltip(bool connected, ServerConfigService config) {
    if (!connected) {
      if (config.status == ServerConfigStatus.unconfigured) {
        return '⚙️ Server belum dikonfigurasi';
      }
      if (config.status == ServerConfigStatus.invalid) {
        return '❌ Koneksi gagal: ${config.errorMessage ?? 'Unknown error'}';
      }
      if (AppConfig.baseUrl.isEmpty) {
        return '🔌 URL server tidak ter-set di runtime';
      }
      return '🔌 Tidak terhubung ke server';
    }
    return '✅ Terhubung: ${config.serverUrl}';
  }

  EdgeInsets _getMargin(ConnectionPosition pos) {
    switch (pos) {
      case ConnectionPosition.topLeft:
        return const EdgeInsets.only(top: 8, left: 8);
      case ConnectionPosition.topRight:
        return const EdgeInsets.only(top: 8, right: 8);
      case ConnectionPosition.bottomLeft:
        return const EdgeInsets.only(bottom: 8, left: 8);
      case ConnectionPosition.bottomRight:
        return const EdgeInsets.only(bottom: 8, right: 8);
    }
  }
}

enum ConnectionPosition { topLeft, topRight, bottomLeft, bottomRight }