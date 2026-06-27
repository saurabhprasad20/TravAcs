/// Application-wide constants.
class AppConstants {
  const AppConstants._();

  /// Display name.
  static const String appName = 'TravAcs';

  /// Hourly assistance rate in INR. This is mirrored from the server, which is
  /// the source of truth (snapshotted per trip in `trips.hourly_rate_inr`).
  /// Kept here only for display/estimation in the UI.
  static const int hourlyRateInr = 135;

  /// Length of the trip-start OTP shared by the requester with the volunteer.
  static const int tripOtpLength = 6;

  /// Length of the SMS login OTP (provider dependent; used for input sizing).
  static const int loginOtpLength = 6;

  /// Resend cooldown for the login OTP, in seconds.
  static const int otpResendCooldownSeconds = 30;
}
