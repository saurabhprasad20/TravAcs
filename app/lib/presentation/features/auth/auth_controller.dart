import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../providers/auth_providers.dart';

/// Drives the phone-OTP flow. State is an [AsyncValue] so screens can show
/// loading and surface [Failure] messages; the action methods also return a
/// bool so the UI can navigate on success.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> requestOtp(String phone) async {
    state = const AsyncLoading();
    final res = await _repo.requestOtp(phone);
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

  Future<bool> verifyOtp({required String phone, required String token}) async {
    state = const AsyncLoading();
    final res = await _repo.verifyOtp(phone: phone, token: token);
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
    await _repo.signOut();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
