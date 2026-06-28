import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'failure.dart';

/// Converts Firebase / network exceptions into domain [Failure]s with friendly,
/// screen-reader-appropriate messages. Repositories funnel all caught errors
/// through this so the UI never sees raw exceptions.
Failure mapFirebaseError(Object error) {
  if (error is FirebaseAuthException) {
    return AuthFailure(_authMessage(error), code: error.code);
  }
  if (error is FirebaseException) {
    // Firestore / Functions errors (e.g. permission-denied, unavailable).
    return ServerFailure(error.message ?? 'Server error.', code: error.code);
  }
  if (error is SocketException || error is TimeoutException) {
    return const NetworkFailure();
  }
  return UnexpectedFailure(error.toString());
}

String _authMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-verification-code':
      return 'That code is incorrect. Please check and try again.';
    case 'invalid-phone-number':
      return 'That phone number looks invalid.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a while and try again.';
    case 'session-expired':
      return 'The code expired. Please request a new one.';
    case 'network-request-failed':
      return 'No internet connection.';
    default:
      return e.message ?? 'Authentication failed. Please try again.';
  }
}
