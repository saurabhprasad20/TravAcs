/// Domain-level error type. Repositories convert exceptions (network, Supabase
/// `PostgrestException`/`AuthException`, RPC error contracts) into a [Failure]
/// carrying a human-readable, accessible [message] and an optional server
/// [code] (see design §6.7 error contract).
sealed class Failure {
  const Failure(this.message, {this.code});

  /// User-facing, screen-reader-friendly message.
  final String message;

  /// Server error code (e.g. `ALREADY_TAKEN`, `NOT_APPROVED`, `OTP_INVALID`).
  final String? code;

  @override
  String toString() => 'Failure(code: $code, message: $message)';
}

/// Network / connectivity problems.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// Authentication / session problems (invalid OTP, expired session, etc.).
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

/// A server-side rule or RPC rejected the operation (mapped from a `code`).
class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

/// Local validation / unexpected/unknown errors.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong.']);
}
