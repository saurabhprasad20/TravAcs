import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Accessibility helpers. Accessibility is a primary requirement for TravAcs
/// (design §11) — status changes, successes, and errors must be announced to
/// screen-reader users (TalkBack / VoiceOver), not just shown visually.
class A11y {
  const A11y._();

  /// Announce [message] to assistive technologies.
  static void announce(
    BuildContext context,
    String message, {
    TextDirection? direction,
  }) {
    final dir = direction ?? Directionality.maybeOf(context) ?? TextDirection.ltr;
    SemanticsService.announce(message, dir);
  }

  /// Reads a numeric OTP digit-by-digit (e.g. "4 8 2 1 0 7") so screen readers
  /// don't pronounce it as a single large number.
  static String spellDigits(String value) => value.split('').join(' ');
}
