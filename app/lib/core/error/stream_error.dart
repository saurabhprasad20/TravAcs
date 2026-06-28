import 'dart:async';

import 'failure.dart';
import 'firebase_error_mapper.dart';

extension StreamErrorMapping<T> on Stream<T> {
  /// Converts any raw error emitted by this stream into a domain [Failure] so
  /// StreamProvider consumers (and the UI) only ever see friendly failures.
  Stream<T> mapErrorToFailure() {
    return transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stack, sink) {
          sink.addError(
            error is Failure ? error : mapFirebaseError(error, stack),
            stack,
          );
        },
      ),
    );
  }
}
