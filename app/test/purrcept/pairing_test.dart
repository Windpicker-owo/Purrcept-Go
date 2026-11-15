/// Untrusted QR codes must reach endpoint review before any credential or network handoff.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:purrcept_go/purrcept/pairing.dart';

void main() {
  final fields = <String, Object>{
    'v': 1,
    'url': 'https://192.0.2.1:8766',
    'certificate_sha256': 'ab' * 32,
    'invitation': 'fake_invitation_for_test_only',
    'expires_at': 1,
  };

  test('endpoint review preserves the exact original submission and normalizes the pin display', () {
    final raw = jsonEncode(fields);
    final parsed = PairingInvitation.parse(raw);
    expect(parsed.host, 'https://192.0.2.1:8766');
    expect(parsed.fingerprint, 'AB' * 32);
    expect(parsed.raw, raw);
    // Engine, rather than the phone wall clock, decides whether this invitation is still valid.
  });

  test('unrelated, malformed, oversized and wrongly typed QR payloads cannot reach pairing', () {
    for (final raw in [
      'https://example.org',
      '[]',
      '{',
      'x' * 4097,
      jsonEncode({...fields, 'v': true}),
      jsonEncode({...fields, 'v': 1.0}),
      jsonEncode({...fields, 'certificate_sha256': 'bad'}),
      jsonEncode({...fields, 'expires_at': false}),
      jsonEncode({...fields, 'invitation': 'short'}),
    ]) {
      expect(() => PairingInvitation.parse(raw), throwsFormatException);
    }
  });

  test('a QR code cannot select cleartext, URL credentials, an extra route or query', () {
    for (final url in [
      'http://192.0.2.1:8766',
      'https://user:secret@example.org',
      'https://example.org/other',
      'https://example.org/?secret=1',
      'https://example.org/#fragment',
      'https://',
    ]) {
      expect(
        () => PairingInvitation.parse(jsonEncode({...fields, 'url': url})),
        throwsFormatException,
      );
    }
  });
}
