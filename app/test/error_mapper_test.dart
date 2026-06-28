import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/error/failure.dart';
import 'package:travacs/core/error/firebase_error_mapper.dart';

void main() {
  group('mapFirebaseError never leaks raw text', () {
    test('Firestore permission-denied -> PermissionFailure, friendly message', () {
      final f = mapFirebaseError(FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      ));
      expect(f, isA<PermissionFailure>());
      expect(f.message.toLowerCase(), isNot(contains('insufficient')));
      expect(f.message.toLowerCase(), isNot(contains('permission-denied')));
      expect(f.debugDetail, isNotNull); // raw kept for logs only
    });

    test('Firestore unavailable -> retryable UnavailableFailure', () {
      final f = mapFirebaseError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
      expect(f, isA<UnavailableFailure>());
      expect(f.isRetryable, isTrue);
    });

    test('SocketException -> NetworkFailure', () {
      final f = mapFirebaseError(const SocketException('no route'));
      expect(f, isA<NetworkFailure>());
      expect(f.message, isNot(contains('no route')));
    });

    test('TimeoutException -> NetworkFailure', () {
      expect(mapFirebaseError(TimeoutException('t')), isA<NetworkFailure>());
    });

    test('unknown error -> UnexpectedFailure with generic message', () {
      final f = mapFirebaseError(Exception('boom internals'));
      expect(f, isA<UnexpectedFailure>());
      expect(f.message, isNot(contains('boom')));
      expect(f.debugDetail, contains('boom'));
    });

    test('an already-mapped Failure passes through unchanged', () {
      const original = NotFoundFailure('Not here.');
      expect(mapFirebaseError(original), same(original));
    });

    test('failureMessage gives generic text for non-Failure', () {
      expect(failureMessage(Exception('x')),
          'Something went wrong. Please try again.');
      expect(failureMessage(const NetworkFailure()),
          contains('internet'));
    });
  });
}
