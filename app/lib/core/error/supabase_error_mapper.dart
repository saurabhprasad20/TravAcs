import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'failure.dart';

/// Converts SDK / network exceptions into domain [Failure]s with friendly,
/// screen-reader-appropriate messages. Repositories funnel all caught errors
/// through this so the UI never sees raw exceptions or stack traces.
Failure mapSupabaseError(Object error) {
  if (error is AuthException) {
    return AuthFailure(error.message, code: error.code ?? '${error.statusCode}');
  }
  if (error is PostgrestException) {
    // RPC error contracts surface here (e.g. ALREADY_TAKEN, NOT_APPROVED).
    return ServerFailure(error.message, code: error.code);
  }
  if (error is SocketException || error is TimeoutException) {
    return const NetworkFailure();
  }
  return UnexpectedFailure(error.toString());
}
