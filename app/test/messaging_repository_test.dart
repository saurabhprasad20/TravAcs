import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:travacs/data/repositories/firebase_messaging_repository.dart';

class _MockMessaging extends Mock implements FirebaseMessaging {}

class _FakeSettings extends Fake implements NotificationSettings {}

/// Guards the crash fix: FCM's `getToken()` can throw a transient
/// `SERVICE_NOT_AVAILABLE` (seen in Crashlytics). registerToken() must swallow
/// it (log non-fatal) and never rethrow / become an uncaught fatal error.
void main() {
  late _MockMessaging messaging;
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late FirebaseMessagingRepository repo;

  setUp(() {
    messaging = _MockMessaging();
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
    // Zero backoff so the retry path doesn't add real delays.
    repo = FirebaseMessagingRepository(messaging, db, auth,
        retryBaseDelay: Duration.zero);
    when(() => messaging.requestPermission())
        .thenAnswer((_) async => _FakeSettings());
  });

  test('registerToken swallows a thrown getToken (never rethrows)', () async {
    when(() => messaging.getToken())
        .thenThrow(FirebaseException(plugin: 'messaging', code: 'unavailable'));

    // Must complete without throwing.
    await expectLater(repo.registerToken(), completes);

    // Nothing was written for the device (token unavailable).
    final toks =
        await db.collection('devices').doc('u1').collection('tokens').get();
    expect(toks.docs, isEmpty);
  });

  test('registerToken retries then succeeds, writing the token', () async {
    var calls = 0;
    when(() => messaging.getToken()).thenAnswer((_) async {
      calls++;
      if (calls < 2) {
        throw FirebaseException(plugin: 'messaging', code: 'unavailable');
      }
      return 'tok-123';
    });

    await repo.registerToken();

    expect(calls, greaterThanOrEqualTo(2));
    final toks =
        await db.collection('devices').doc('u1').collection('tokens').get();
    expect(toks.docs.map((d) => d.id), contains('tok-123'));
  });

  test('registerToken is a no-op when signed out', () async {
    final signedOut = FirebaseMessagingRepository(
        messaging, db, MockFirebaseAuth(),
        retryBaseDelay: Duration.zero);
    await signedOut.registerToken();
    verifyNever(() => messaging.getToken());
  });
}
