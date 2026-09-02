/// Application-wide constants.
class AppConstants {
  const AppConstants._();

  /// Display name.
  static const String appName = 'TravAcs';

  /// App version shown in the menu / About dialog. Keep in sync with the
  /// `version:` in pubspec.yaml.
  static const String appVersion = '1.0.0';

  /// Support contacts shown on the Contact-us screen.
  static const String supportEmail = 'support@travacs.in';
  static const String supportPhone = '+91 73109 33165';
  static const String website = 'travacs.in';
  static const String publicPolicyBaseUrl = 'https://travacs-dev.web.app';
  static const String termsUrl = '$publicPolicyBaseUrl/termsandconditions';
  static const String privacyPolicyUrl = '$publicPolicyBaseUrl/privacypolicies';
  static const String accountDeletionUrl =
      '$publicPolicyBaseUrl/accountdeletion';

  /// Per-hour service charge for a TravAcser serving a SINGLE traveller.
  /// Mirrored from the server (the billing source of truth); kept here only for
  /// display/estimation in the UI.
  static const int rateSoloInr = 149;

  /// Per-hour service charge for a TravAcser serving TWO travellers (one
  /// TravAcser assists up to two people).
  static const int ratePairInr = 210;

  /// Flat travel cost in INR added PER TravAcser (multiplied by the number of
  /// TravAcsers on the trip) to cover each TravAcser reaching the meeting point.
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

  /// Minimum lead time between "now" and a new trip's scheduled start — a trip
  /// can't be created in the past or for the immediate moment. Mirrored on the
  /// server (the Firestore create rule additionally rejects a past start).
  static const Duration minScheduleLeadTime = Duration(minutes: 2);
}
