import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/firebase_error_mapper.dart';
import '../../core/error/result.dart';
import '../../domain/repositories/auth_repository.dart';

/// Firebase Phone Auth implementation of [AuthRepository] (design §7).
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Stream<String?> get authStateChanges =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  FutureResult<String> requestOtp(String phone) async {
    // verifyPhoneNumber is callback-based; bridge it to a Future that yields
    // the verificationId (or a Failure). We intentionally ignore Android's
    // auto-retrieval (verificationCompleted) so the UX is a consistent
    // "enter the code" step on both platforms.
    final completer = Completer<Result<String>>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          if (!completer.isCompleted) {
            completer.complete(failure(mapFirebaseError(e)));
          }
        },
        codeSent: (verificationId, _) {
          if (!completer.isCompleted) {
            completer.complete(success(verificationId));
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!completer.isCompleted) {
            completer.complete(success(verificationId));
          }
        },
      );
    } catch (e) {
      if (!completer.isCompleted) completer.complete(failure(mapFirebaseError(e)));
    }
    return completer.future;
  }

  @override
  FutureResult<Unit> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  FutureResult<Unit> signOut() async {
    try {
      await _auth.signOut();
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }
}
