import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/result.dart';

/// Authentication abstraction (design §7). v1 uses phone + OTP as the primary
/// login. The interface is intentionally provider-agnostic so an
/// email/password method (a future alternate) can be added without touching
/// the domain or UI layers.
abstract interface class AuthRepository {
  /// The current session, or null if signed out.
  Session? get currentSession;

  /// The current user, or null if signed out.
  User? get currentUser;

  /// Emits on sign-in, sign-out and token refresh.
  Stream<AuthState> get authStateChanges;

  /// Sends an SMS OTP to [phone] (E.164, e.g. +9198XXXXXXXX).
  FutureResult<Unit> requestOtp(String phone);

  /// Verifies the SMS [token] for [phone], establishing a session.
  FutureResult<Unit> verifyOtp({required String phone, required String token});

  /// Signs the current user out.
  FutureResult<Unit> signOut();
}
