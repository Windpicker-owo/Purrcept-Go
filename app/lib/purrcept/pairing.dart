/// Validates untrusted QR/clipboard invitations for review; native pairing owns TLS and credentials.
library;

import 'dart:convert';

/// A reviewed endpoint and certificate pin. The short-lived secret stays only in the original text.
class PairingInvitation {
  const PairingInvitation._(this.raw, this.host, this.fingerprint);

  final String raw;
  final String host;
  final String fingerprint;

  /// Reject unrelated QR codes before any network request. Engine remains the expiry authority;
  /// a phone's wall clock must not make an otherwise valid server invitation unusable.
  factory PairingInvitation.parse(String raw) {
    if (utf8.encode(raw).length > 4096) {
      throw const FormatException('invalid_invitation');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['v'] is! int ||
        value['v'] != 1) {
      throw const FormatException('invalid_invitation');
    }
    final url = value['url'];
    final fingerprint = value['certificate_sha256'];
    final invitation = value['invitation'];
    final expires = value['expires_at'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        fingerprint is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(fingerprint) ||
        invitation is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{16,256}$').hasMatch(invitation) ||
        expires is! num ||
        !expires.isFinite ||
        expires <= 0) {
      throw const FormatException('invalid_invitation');
    }
    return PairingInvitation._(raw, uri.origin, fingerprint.toUpperCase());
  }
}
