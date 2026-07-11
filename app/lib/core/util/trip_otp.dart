import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../config/constants.dart';

/// Deterministic, offline trip-start OTP (point 11).
///
/// The TravAcser's app shows this code; the User enters it when they meet, on
/// or after the scheduled time. Both apps read the same assignment document, so
/// they compute the **same** code from the shared fields — no SMS/OTP provider
/// and no server round-trip are needed. Because [scheduledStartAt] is part of
/// the input, a rescheduled trip automatically gets a new code.
///
/// The algorithm is an RFC-4226-style HMAC-SHA256 truncation, reduced to
/// [AppConstants.tripOtpLength] digits. The salt is a fixed app constant (not a
/// secret — see [AppConstants.tripOtpSalt]); the OTP only confirms the two
/// parties are together, it is not a security token.
String tripStartOtp({
  required String? userPhone,
  required String? travAcserPhone,
  required DateTime scheduledStartAt,
}) {
  final material = '${_normalisePhone(userPhone)}|'
      '${_normalisePhone(travAcserPhone)}|'
      '${scheduledStartAt.millisecondsSinceEpoch}';

  final digest = Hmac(sha256, utf8.encode(AppConstants.tripOtpSalt))
      .convert(utf8.encode(material))
      .bytes;

  // Dynamic truncation (RFC 4226 §5.3): use the low nibble of the last byte as
  // an offset into the digest, then take 31 bits as a positive integer.
  final offset = digest[digest.length - 1] & 0x0f;
  final binary = ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);

  final mod = _pow10(AppConstants.tripOtpLength);
  return (binary % mod).toString().padLeft(AppConstants.tripOtpLength, '0');
}

/// Keeps digits only and, for numbers with a country code, the last 10 digits,
/// so `+919760599211` and `9760599211` produce the same OTP on both sides.
String _normalisePhone(String? phone) {
  if (phone == null) return '';
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

int _pow10(int n) {
  var v = 1;
  for (var i = 0; i < n; i++) {
    v *= 10;
  }
  return v;
}
