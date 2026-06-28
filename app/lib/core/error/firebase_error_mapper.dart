import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'error_reporter.dart';
import 'failure.dart';

/// Converts **any** caught error into a domain [Failure] with a friendly,
/// screen-reader-appropriate message. Raw text goes only into `debugDetail`
/// (logged, never shown). Repositories funnel all errors through this.
Failure mapFirebaseError(Object error, [StackTrace? stack]) {
  final failure = _classify(error);
  ErrorReporter.reportNonFatal(failure);
  return failure;
}

Failure _classify(Object error) {
  // NOTE: FirebaseFunctionsException is a subclass of FirebaseException, so it
  // MUST be checked first.
  if (error is FirebaseFunctionsException) {
    return _functions(error);
  }
  if (error is FirebaseAuthException) {
    return AuthFailure(_authMessage(error), code: error.code, debugDetail: error.message);
  }
  if (error is FirebaseException) {
    return _firebase(error);
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException) {
    return NetworkFailure(debugDetail: error.toString());
  }
  if (error is Failure) return error; // already mapped
  return UnexpectedFailure(debugDetail: error.toString());
}

// --- Cloud Functions (callables) ------------------------------------------
Failure _functions(FirebaseFunctionsException e) {
  final raw = e.message;
  final detail = '${e.code}: ${e.message}';
  switch (e.code) {
    case 'unauthenticated':
      return AuthFailure('Please sign in and try again.', code: e.code, debugDetail: detail);
    case 'permission-denied':
      return PermissionFailure(raw ?? "You don't have permission to do that.",
          code: e.code, debugDetail: detail);
    case 'not-found':
      return NotFoundFailure(raw ?? "We couldn't find that.", code: e.code, debugDetail: detail);
    case 'already-exists':
      return ConflictFailure(raw ?? 'That has already been done.', code: e.code, debugDetail: detail);
    case 'failed-precondition':
      // Our callables set user-facing messages for these (e.g. "All slots filled").
      return ConflictFailure(raw ?? "That can't be done right now.", code: e.code, debugDetail: detail);
    case 'resource-exhausted':
      return RateLimitFailure(
          message: raw ?? 'Too many attempts. Please wait and try again.',
          code: e.code, debugDetail: detail);
    case 'invalid-argument':
      return ValidationFailure(raw ?? 'Please check your input and try again.',
          code: e.code, debugDetail: detail);
    case 'unavailable':
    case 'deadline-exceeded':
      return UnavailableFailure(code: e.code, debugDetail: detail);
    default: // internal, unknown, etc.
      return ServerFailure(code: e.code, debugDetail: detail);
  }
}

// --- Firestore / Storage / App Check --------------------------------------
Failure _firebase(FirebaseException e) {
  final detail = '${e.code}: ${e.message}';
  switch (e.code) {
    case 'permission-denied':
      return PermissionFailure("You don't have access to do that.",
          code: e.code, debugDetail: detail);
    case 'not-found':
      return NotFoundFailure("We couldn't find that.", code: e.code, debugDetail: detail);
    case 'unavailable':
    case 'deadline-exceeded':
    case 'aborted':
      return UnavailableFailure(code: e.code, debugDetail: detail);
    case 'resource-exhausted':
      return RateLimitFailure(code: e.code, debugDetail: detail);
    case 'unauthenticated':
      return AuthFailure('Please sign in and try again.', code: e.code, debugDetail: detail);
    case 'cancelled':
      return UnavailableFailure(message: 'The action was interrupted. Please try again.',
          code: e.code, debugDetail: detail);
    default: // failed-precondition (e.g. missing index), internal, etc.
      return ServerFailure(code: e.code, debugDetail: detail);
  }
}

// --- Firebase Auth ---------------------------------------------------------
String _authMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-verification-code':
      return 'That code is incorrect. Please check and try again.';
    case 'invalid-phone-number':
      return 'That phone number looks invalid.';
    case 'too-many-requests':
    case 'quota-exceeded':
      return 'Too many attempts. Please wait a while and try again.';
    case 'session-expired':
    case 'code-expired':
      return 'The code expired. Please request a new one.';
    case 'network-request-failed':
      return 'No internet connection. Please check your network and try again.';
    case 'operation-not-allowed':
      return 'Phone sign-in is currently unavailable. Please try again later.';
    case 'app-not-authorized':
    case 'missing-client-identifier':
    case 'captcha-check-failed':
      return "We couldn't verify this device. Please update the app or try again.";
    case 'user-disabled':
      return 'This account has been disabled. Please contact support.';
    case 'invalid-verification-id':
      return 'Your session expired. Please request a new code.';
    default:
      return 'Sign-in failed. Please try again.';
  }
}
