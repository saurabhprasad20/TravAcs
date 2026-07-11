/// Application-wide constants.
class AppConstants {
  const AppConstants._();

  /// Display name.
  static const String appName = 'TravAcs';

  /// App version shown in the menu / About dialog. Keep in sync with the
  /// `version:` in pubspec.yaml.
  static const String appVersion = '1.0.0';

  /// Placeholder support contacts shown on the Contact-us screen (replace with
  /// real values before store release).
  static const String supportEmail = 'support@travacs.example';
  static const String supportPhone = '+91 00000 00000';

  /// Hourly assistance rate in INR (the TravAcser's time/service charge). Trip
  /// time is billed in [billingBlockMinutes] blocks rounded UP to the next half
  /// hour (e.g. a 4h58m trip bills as 5h). Mirrored from the server, which is
  /// the source of truth; kept here only for display/estimation in the UI.
  static const int hourlyRateInr = 140;

  /// Billing granularity in minutes: trip time is rounded UP to the next
  /// multiple of this before applying [hourlyRateInr].
  static const int billingBlockMinutes = 30;

  /// Flat travel cost in INR added ONCE per trip (not per TravAcser) to cover
  /// the TravAcser reaching the meeting point.
  static const int travelCostInr = 100;

  /// Length of the trip-start OTP shared by the requester with the volunteer.
  static const int tripOtpLength = 4;

  /// Fixed salt for the deterministic trip-start OTP (point 11). This is NOT a
  /// secret — it ships in the app and only makes the code deterministic on both
  /// sides. The OTP merely confirms the two parties are physically together; it
  /// is generated on the TravAcser's device and validated on the User's, both
  /// computing it from the same assignment fields (phones + scheduled time), so
  /// no SMS/OTP provider or server round-trip is involved.
  static const String tripOtpSalt = 'travacs-trip-otp-v1';

  /// Length of the SMS login OTP (provider dependent; used for input sizing).
  static const int loginOtpLength = 6;

  /// Resend cooldown for the login OTP, in seconds.
  static const int otpResendCooldownSeconds = 30;
}
