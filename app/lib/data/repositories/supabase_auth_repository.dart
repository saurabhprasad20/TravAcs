import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/result.dart';
import '../../core/error/supabase_error_mapper.dart';
import '../../domain/repositories/auth_repository.dart';

/// Supabase-backed [AuthRepository] using phone + SMS OTP (design §7).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  Session? get currentSession => _auth.currentSession;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  @override
  FutureResult<Unit> requestOtp(String phone) async {
    try {
      await _auth.signInWithOtp(phone: phone);
      return success(unit);
    } catch (e) {
      return failure(mapSupabaseError(e));
    }
  }

  @override
  FutureResult<Unit> verifyOtp({
    required String phone,
    required String token,
  }) async {
    try {
      await _auth.verifyOTP(
        type: OtpType.sms,
        phone: phone,
        token: token,
      );
      return success(unit);
    } catch (e) {
      return failure(mapSupabaseError(e));
    }
  }

  @override
  FutureResult<Unit> signOut() async {
    try {
      await _auth.signOut();
      return success(unit);
    } catch (e) {
      return failure(mapSupabaseError(e));
    }
  }
}
