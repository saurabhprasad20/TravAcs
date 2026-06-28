/// Domain-level error type. Repositories convert *every* caught exception into
/// a [Failure] (via `mapFirebaseError`) carrying a **human-readable, accessible**
/// [message]. Raw exception text lives ONLY in [debugDetail] (for logs /
/// Crashlytics) and is never shown to the user.
sealed class Failure {
  const Failure(
    this.message, {
    this.code,
    this.debugDetail,
    this.isRetryable = false,
  });

  /// User-facing, screen-reader-friendly message. Never contains raw error text.
  final String message;

  /// Machine code (e.g. `permission-denied`, `ALREADY_TAKEN`) — for handling/logs.
  final String? code;

  /// Raw underlying detail (exception message / toString). **Logs only.**
  final String? debugDetail;

  /// Whether retrying the same action might succeed (transient failures).
  final bool isRetryable;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

/// No / lost connectivity, timeouts.
class NetworkFailure extends Failure {
  const NetworkFailure({String? code, String? debugDetail})
      : super(
          'No internet connection. Please check your network and try again.',
          code: code,
          debugDetail: debugDetail,
          isRetryable: true,
        );
}

/// Authentication / session / OTP problems.
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code, super.debugDetail});
}

/// The caller isn't allowed to perform the action.
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.code, super.debugDetail});
}

/// The requested item doesn't exist (any more).
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.code, super.debugDetail});
}

/// State conflict — already taken / already exists / already done.
class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.code, super.debugDetail});
}

/// Too many attempts / quota exceeded.
class RateLimitFailure extends Failure {
  const RateLimitFailure({
    String message = 'Too many attempts. Please wait a moment and try again.',
    String? code,
    String? debugDetail,
  }) : super(message, code: code, debugDetail: debugDetail, isRetryable: true);
}

/// Invalid input (client- or server-side validation).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code, super.debugDetail});
}

/// Service temporarily unavailable / deadline exceeded (transient).
class UnavailableFailure extends Failure {
  const UnavailableFailure({
    String message =
        'The service is temporarily unavailable. Please try again shortly.',
    String? code,
    String? debugDetail,
  }) : super(message, code: code, debugDetail: debugDetail, isRetryable: true);
}

/// A generic server-side error (internal/unknown backend failure).
class ServerFailure extends Failure {
  const ServerFailure({String? code, String? debugDetail})
      : super(
          'Something went wrong on our side. Please try again.',
          code: code,
          debugDetail: debugDetail,
        );
}

/// Anything we couldn't classify. Generic message; raw text only in debugDetail.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({String? debugDetail})
      : super('Something went wrong. Please try again.',
            debugDetail: debugDetail);
}

/// The user-facing message for any error (Failure or not). UI must use this and
/// NEVER `error.toString()`.
String failureMessage(Object? error) =>
    error is Failure ? error.message : 'Something went wrong. Please try again.';
