import 'package:fpdart/fpdart.dart';

import '../../core/error/result.dart';

/// Authentication abstraction (design §7). v1 uses Firebase Phone Auth (SMS
/// OTP). Framework-free: exposes only the user id, not any SDK type, so the
/// backend can be swapped (as the Supabase→Firebase migration did) without
/// touching the domain or UI.
abstract interface class AuthRepository {
  /// The current user's id (Firebase uid), or null if signed out.
  String? get currentUserId;

  /// Emits the current uid on sign-in / sign-out / token refresh (null = out).
  Stream<String?> get authStateChanges;

  /// Starts phone verification: triggers an SMS to [phone] (E.164, e.g.
  /// +9198XXXXXXXX) and returns a `verificationId` to pair with the code.
  FutureResult<String> requestOtp(String phone);

  /// Completes sign-in with the [smsCode] for a prior [verificationId].
  FutureResult<Unit> verifyOtp({
    required String verificationId,
    required String smsCode,
  });

  /// Signs the current user out.
  FutureResult<Unit> signOut();
}
