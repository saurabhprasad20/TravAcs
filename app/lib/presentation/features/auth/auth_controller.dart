import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../providers/auth_providers.dart';

/// Drives the phone-OTP flow (Firebase). State is an [AsyncValue] so screens can
/// show loading and surface [Failure] messages; action methods return a bool so
/// the UI can navigate on success. The `verificationId` from step 1 is held
/// here and consumed by step 2.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  String? _verificationId;
  String? phone;

  /// Step 1: send the SMS code. On success, stores the verificationId.
  Future<bool> requestOtp(String phone) async {
    state = const AsyncLoading();
    final res = await _repo.requestOtp(phone);
    return res.match(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
      (verificationId) {
        _verificationId = verificationId;
        this.phone = phone;
        state = const AsyncData(null);
        return true;
      },
    );
  }

  /// Step 2: verify the entered [smsCode] against the stored verificationId.
  Future<bool> verifyOtp(String smsCode) async {
    final vid = _verificationId;
    if (vid == null) {
      state = AsyncError(
        const AuthFailure('Please request a new code.'),
        StackTrace.current,
      );
      return false;
    }
    state = const AsyncLoading();
    final res = await _repo.verifyOtp(verificationId: vid, smsCode: smsCode);
    return res.match(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  Future<void> signOut() async {
    _verificationId = null;
    phone = null;
    await _repo.signOut();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
