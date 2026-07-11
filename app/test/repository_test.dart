import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:travacs/core/error/failure.dart';
import 'package:travacs/data/repositories/firebase_auth_repository.dart';
import 'package:travacs/data/repositories/firestore_profile_repository.dart';
import 'package:travacs/data/repositories/firestore_request_repository.dart';
import 'package:travacs/domain/entities/city.dart';
import 'package:travacs/domain/entities/enums.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _FakeCallableResult extends Fake implements HttpsCallableResult<dynamic> {}

/// Repository unit tests (M10a) using in-memory fakes — no network, no
/// emulator. Locks down write shapes, query filters, and the
/// failure-not-throw contract.
void main() {
  final city = City.fromWire('delhi_ncr')!;
  final otherCity = City.fromWire('mumbai')!;

  group('FirestoreProfileRepository', () {
    late FakeFirebaseFirestore db;
    late MockFirebaseAuth auth;
    late FirestoreProfileRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
      repo = FirestoreProfileRepository(db, auth);
    });

    test('getMyProfile returns null before registration', () async {
      final r = await repo.getMyProfile();
      expect(r.isRight(), isTrue);
      expect(r.getOrElse((_) => throw 'left'), isNull);
    });

    test('not signed in -> AuthFailure (does not throw)', () async {
      final signedOut = FirestoreProfileRepository(db, MockFirebaseAuth());
      final r = await signedOut.getMyProfile();
      r.fold((f) => expect(f, isA<AuthFailure>()), (_) => fail('expected Left'));
    });

    test('saveProfile creates a volunteer with server-managed defaults',
        () async {
      final saved = await repo.saveProfile(
        role: UserRole.volunteer,
        fullName: 'Asha',
        state: Region.delhiNcr,
        city: city,
        address: 'Some address',
      );
      expect(saved.isRight(), isTrue);

      final doc = (await db.collection('profiles').doc('u1').get()).data()!;
      expect(doc['role'], 'volunteer');
      expect(doc['verificationStatus'], 'pending');
      expect(doc['isActive'], true);
      expect(doc['ratingAvg'], 0);

      final me = (await repo.getMyProfile()).getOrElse((_) => throw 'left')!;
      expect(me.profile.isVolunteer, isTrue);
      expect(me.volunteer!.isApproved, isFalse);
    });

    test('saveProfile update cannot flip role or reset verification', () async {
      await repo.saveProfile(
        role: UserRole.volunteer,
        fullName: 'Asha',
        state: Region.delhiNcr,
        city: city,
        address: 'A',
      );
      // Second save attempts to become a requester with a new name.
      await repo.saveProfile(
        role: UserRole.requester,
        fullName: 'Asha Rao',
        state: Region.delhiNcr,
        city: city,
        homeLocationText: 'Home',
      );

      final doc = (await db.collection('profiles').doc('u1').get()).data()!;
      expect(doc['role'], 'volunteer'); // immutable on the client
      expect(doc['verificationStatus'], 'pending'); // not reset
      expect(doc['fullName'], 'Asha Rao'); // editable field updated
    });

    test('setAvailability toggles isActive', () async {
      await repo.saveProfile(
        role: UserRole.volunteer,
        fullName: 'Asha',
        state: Region.delhiNcr,
        city: city,
        address: 'A',
      );
      await repo.setAvailability(false);
      final doc = (await db.collection('profiles').doc('u1').get()).data()!;
      expect(doc['isActive'], false);
    });
  });

  group('FirestoreRequestRepository', () {
    late FakeFirebaseFirestore db;
    late MockFirebaseAuth auth;
    late _MockFunctions functions;
    late FirestoreRequestRepository repo;

    setUpAll(() => registerFallbackValue(<String, dynamic>{}));

    setUp(() {
      db = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
      functions = _MockFunctions();
      repo = FirestoreRequestRepository(db, auth, functions);
    });

    Future<String> createSample({City? inCity, String requester = 'u1'}) async {
      final r = await FirestoreRequestRepository(
        db,
        MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: requester)),
        functions,
      ).createRequest(
        serviceState: Region.delhiNcr,
        serviceCity: inCity ?? city,
        requesterName: 'U',
        numTravellers: 2,
        numTravAcsers: 1,
        genderPreference: GenderPreference.preferSameGender,
        scheduledDate: DateTime(2026, 7, 1),
        startTime: '10:00',
        expectedDurationMinutes: 120,
        meetingPoint: 'A',
        destination: 'B',
      );
      return r.getOrElse((_) => throw 'create failed');
    }

    test('createRequest writes broadcast doc with computed estimate', () async {
      final id = await createSample();
      final doc = (await db.collection('requests').doc(id).get()).data()!;
      expect(doc['status'], 'broadcast');
      expect(doc['acceptedCount'], 0);
      expect(doc['volunteerId'], isNull);
      expect(doc['serviceCity'], 'delhi_ncr');
      expect(doc['estimatedAmountInr'], 380); // 2h=4 blocks*₹70=280 *1 + ₹100 travel
      expect(doc['genderPreference'], 'prefer_same_gender');
      expect(doc['scheduledStartAt'], isNotNull); // auto-start anchor
    });

    test('watchMyRequests returns only the caller\'s requests', () async {
      await createSample(requester: 'u1');
      await createSample(requester: 'someone_else');
      final list = await repo.watchMyRequests().first;
      expect(list.length, 1);
      expect(list.single.requesterId, 'u1');
    });

    test('watchAvailableRequests filters by city and broadcast status',
        () async {
      final here = await createSample(inCity: city);
      await createSample(inCity: otherCity);
      // Cancel one in-city request: it must drop out of "available".
      final extra = await createSample(inCity: city);
      await repo.cancelRequest(extra);

      final list = await repo.watchAvailableRequests(city).first;
      expect(list.map((r) => r.id), contains(here));
      expect(list.every((r) => r.serviceCity == city), isTrue);
      expect(list.any((r) => r.id == extra), isFalse); // cancelled
    });

    test('acceptRequest returns Right when the callable succeeds', () async {
      final callable = _MockCallable();
      when(() => functions.httpsCallable('acceptRequest')).thenReturn(callable);
      when(() => callable.call<dynamic>(any()))
          .thenAnswer((_) async => _FakeCallableResult());

      final r = await repo.acceptRequest('req1');
      expect(r.isRight(), isTrue);
      verify(() => callable.call<dynamic>({'requestId': 'req1'})).called(1);
    });

    test('acceptRequest maps a thrown error to a Failure (never rethrows)',
        () async {
      final callable = _MockCallable();
      when(() => functions.httpsCallable('acceptRequest')).thenReturn(callable);
      when(() => callable.call<dynamic>(any()))
          .thenThrow(Exception('boom'));

      final r = await repo.acceptRequest('req1');
      r.fold((f) => expect(f, isA<Failure>()), (_) => fail('expected Left'));
    });
  });

  group('FirebaseAuthRepository', () {
    test('isAdmin is false when signed out', () async {
      final repo = FirebaseAuthRepository(MockFirebaseAuth());
      expect(await repo.isAdmin(), isFalse);
    });

    test('currentUserId reflects the signed-in user', () {
      final repo = FirebaseAuthRepository(
          MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u9')));
      expect(repo.currentUserId, 'u9');
    });

    test('signOut clears the session', () async {
      final auth =
          MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u9'));
      final repo = FirebaseAuthRepository(auth);
      final r = await repo.signOut();
      expect(r.isRight(), isTrue);
      expect(auth.currentUser, isNull);
    });
  });
}
