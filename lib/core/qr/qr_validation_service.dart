import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../config/app_config.dart';

class QrValidationResult {
  const QrValidationResult({required this.isValid, this.reason, this.payload, required this.isLegacy});
  final bool isValid;
  final String? reason;
  final Map<String, dynamic>? payload;
  final bool isLegacy;
}

class QrValidationService {
  QrValidationService({required List<String> activeSecrets, this.maxClockSkew = const Duration(minutes: 2)}) : _activeSecrets = activeSecrets;

  final List<String> _activeSecrets;
  final Duration maxClockSkew;

  QrValidationResult validate(String rawCode) {
    if (!AppConfig.enableSignedQr || !rawCode.startsWith('vms1.')) {
      return const QrValidationResult(isValid: true, isLegacy: true);
    }

    try {
      final parts = rawCode.split('.');
      if (parts.length != 4) {
        return const QrValidationResult(isValid: false, isLegacy: false, reason: 'Malformed signed QR');
      }

      final payloadRaw = parts[2];
      final signature = parts[3];
      final payloadJson = utf8.decode(base64Url.decode(base64Url.normalize(payloadRaw)));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      final signed = _activeSecrets.any((secret) {
        final digest = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payloadRaw));
        return base64Url.encode(digest.bytes).replaceAll('=', '') == signature;
      });
      if (!signed) {
        return const QrValidationResult(isValid: false, isLegacy: false, reason: 'QR signature verification failed');
      }

      final now = DateTime.now().toUtc();
      final exp = DateTime.tryParse((payload['exp'] ?? '').toString())?.toUtc();
      final iat = DateTime.tryParse((payload['iat'] ?? '').toString())?.toUtc();

      if (exp == null || iat == null) {
        return const QrValidationResult(isValid: false, isLegacy: false, reason: 'Missing temporal claims');
      }
      if (now.isAfter(exp.add(maxClockSkew))) {
        return const QrValidationResult(isValid: false, isLegacy: false, reason: 'QR token expired');
      }
      if (iat.isAfter(now.add(maxClockSkew))) {
        return const QrValidationResult(isValid: false, isLegacy: false, reason: 'QR issued in the future');
      }

      return QrValidationResult(isValid: true, payload: payload, isLegacy: false);
    } catch (_) {
      return const QrValidationResult(isValid: false, isLegacy: false, reason: 'Invalid QR payload');
    }
  }
}
