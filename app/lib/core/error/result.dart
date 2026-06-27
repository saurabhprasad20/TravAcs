import 'package:fpdart/fpdart.dart';

import 'failure.dart';

/// A synchronous result: either a [Failure] (left) or a value [T] (right).
///
/// Repositories and use cases return [Result] so that error handling is
/// explicit and the UI layer can map failures to accessible messages without
/// try/catch scattered across widgets.
typedef Result<T> = Either<Failure, T>;

/// A result of an asynchronous operation.
typedef FutureResult<T> = Future<Result<T>>;

/// Convenience constructors.
Result<T> success<T>(T value) => Right(value);
Result<T> failure<T>(Failure f) => Left(f);
