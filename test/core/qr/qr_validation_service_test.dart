import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_vms/core/qr/qr_validation_service.dart';

void main() {
  test('accepts valid signed qr payload', () {
    const secret = 's1';
    final payload = base64Url.encode(utf8.encode(jsonEncode({'iat': '2026-05-27T00:00:00Z', 'exp': '2099-01-01T00:00:00Z'}))).replaceAll('=', '');
    final sig = base64Url.encode(Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload)).bytes).replaceAll('=', '');
    final raw = 'vms1.qr.$payload.$sig';

    final svc = QrValidationService(activeSecrets: const [secret]);
    expect(svc.validate(raw).isValid, isTrue);
  });

  test('rejects malformed signed payload safely', () {
    final svc = QrValidationService(activeSecrets: const ['s1']);
    final result = svc.validate('vms1.qr.not_base64.invalid');
    expect(result.isValid, isFalse);
    expect(result.reason, isNotNull);
  });

}

