import 'package:flutter/material.dart';
import '../../config/app_config.dart';

enum ConnectionPosition { topLeft, topRight, bottomLeft, bottomRight }

class ConnectionIndicator extends StatelessWidget {
  final ConnectionPosition position;
  final bool showText;

  const ConnectionIndicator({
    super.key,
    this.position = ConnectionPosition.topRight,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = AppConfig.baseUrl.isNotEmpty;
    final color = isConnected ? Colors.green : Colors.red;
    final label = isConnected ? 'Online' : 'Offline';
    final tooltip = isConnected
        ? '✅ Terhubung: ${AppConfig.baseUrl}'
        : '❌ Tidak terhubung - Server URL belum valid';

    return Tooltip(
      message: tooltip,
      child: Container(
        margin: _getMargin(position),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            if (showText) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
