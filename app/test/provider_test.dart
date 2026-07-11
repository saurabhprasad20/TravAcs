import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:travacs/core/error/failure.dart';
import 'package:travacs/core/error/result.dart';
import 'package:travacs/domain/entities/assignment.dart';
import 'package:travacs/domain/entities/city.dart';
import 'package:travacs/domain/entities/enums.dart';
import 'package:travacs/domain/entities/profile.dart';
import 'package:travacs/domain/entities/request.dart';
import 'package:travacs/domain/repositories/profile_repository.dart';
import 'package:travacs/domain/repositories/request_repository.dart';
import 'package:travacs/presentation/providers/auth_providers.dart';
import 'package:travacs/presentation/providers/profile_providers.dart';
import 'package:travacs/presentation/providers/request_providers.dart';

class _MockRequestRepo extends Mock implements RequestRepository {}

class _MockProfileRepo extends Mock implements ProfileRepository {}

/// Riverpod provider tests (M10a): override the repository providers with
/// in-memory stubs and assert the derived/filtering logic.
void main() {
  final city = City.fromWire('delhi_ncr')!;

  setUpAll(() => registerFallbackValue(city));

  Request req(String id, {DateTime? startAt}) => Request(
        id: id,
        requesterId: 'u$id',
        status: RequestStatus.broadcast,
        serviceState: Region.delhiNcr,
        serviceCity: city,
        numTravellers: 1,
        numTravAcsers: 1,
        genderPreference: GenderPreference.anyGender,
        scheduledDate: startAt ?? DateTime.now().add(const Duration(days: 1)),
        startTime: '10:00',
        scheduledStartAt: startAt ?? DateTime.now().add(const Duration(days: 1)),
        expectedDurationMinutes: 60,
        meetingPoint: 'A',
        destination: 'B',
        estimatedAmountInr: 135,
      );

  Assignment assignmentFor(String requestId) => Assignment(
        requestId: requestId,
        volunteerId: 'v1',
        volunteerName: 'V',
        requesterId: 'u1',
        requesterName: 'U',
        scheduledDate: DateTime(2026, 7, 1),
        startTime: '10:00',
        expectedDurationMinutes: 60,
        meetingPoint: 'A',
        destination: 'B',
        numTravellers: 1,
        amountInrEstimate: 135,
        tripStatus: TripStatus.assigned,
      );

  MyProfile profile({required bool approved, City? withCity}) => MyProfile(
        profile: Profile(
          id: 'v1',
          role: UserRole.volunteer,
          fullName: 'V',
          serviceArea: withCity == null ? null : Region.delhiNcr,
          serviceCity: withCity,
        ),
        volunteer: VolunteerProfile(
          profileId: 'v1',
          verificationStatus: approved
              ? VerificationStatus.approved
              : VerificationStatus.pending,
        ),
      );

  ProviderContainer makeContainer({
    required MyProfile myProfile,
    required List<Request> available,
    required List<Assignment> myAssignments,
  }) {
    final repo = _MockRequestRepo();
    when(() => repo.watchAvailableRequests(any()))
        .thenAnswer((_) => Stream.value(available));

    final container = ProviderContainer(overrides: [
      requestRepositoryProvider.overrideWithValue(repo),
      myProfileProvider.overrideWith((ref) async => myProfile),
      myAssignmentsProvider.overrideWith((ref) => Stream.value(myAssignments)),
    ]);
    addTearDown(container.dispose);
    // Keep the async deps alive so availableRequestsProvider can read .value.
    container.listen(myProfileProvider, (_, __) {}, fireImmediately: true);
    container.listen(myAssignmentsProvider, (_, __) {}, fireImmediately: true);
    container.listen(availableRequestsProvider, (_, __) {}, fireImmediately: true);
    return container;
  }

  Future<List<Request>> readAvailable(ProviderContainer c) async {
    await c.read(myProfileProvider.future);
    await c.read(myAssignmentsProvider.future);
    await Future<void>.delayed(Duration.zero);
    return c.read(availableRequestsProvider.future);
  }

  group('availableRequestsProvider', () {
    test('approved volunteer sees in-city requests, minus already-accepted',
        () async {
      final c = makeContainer(
        myProfile: profile(approved: true, withCity: city),
        available: [req('A'), req('B')],
        myAssignments: [assignmentFor('B')], // already accepted B
      );
      final list = await readAvailable(c);
      expect(list.map((r) => r.id), ['A']);
    });

    test('empty when the volunteer is not approved', () async {
      final c = makeContainer(
        myProfile: profile(approved: false, withCity: city),
        available: [req('A')],
        myAssignments: const [],
      );
      expect(await readAvailable(c), isEmpty);
    });

    test('empty when no service city is set', () async {
      final c = makeContainer(
        myProfile: profile(approved: true, withCity: null),
        available: [req('A')],
        myAssignments: const [],
      );
      expect(await readAvailable(c), isEmpty);
    });

    test('shows short-notice requests, hides only past-start ones', () async {
      final c = makeContainer(
        myProfile: profile(approved: true, withCity: city),
        available: [
          req('SOON', startAt: DateTime.now().add(const Duration(minutes: 10))),
          req('PAST', startAt: DateTime.now().subtract(const Duration(hours: 1))),
          req('OK'), // tomorrow -> visible
        ],
        myAssignments: const [],
      );
      // SOON (10 min out) is now visible; only PAST (past start) is hidden.
      expect((await readAvailable(c)).map((r) => r.id).toSet(), {'SOON', 'OK'});
    });
  });

  group('myProfileProvider', () {
    // The auth stream emitting 'u1' rebuilds the FutureProvider, so we let it
    // settle and read the final AsyncValue rather than await a future that the
    // rebuild replaces.
    Future<AsyncValue<MyProfile?>> settledProfile(
      Result<MyProfile?> Function() stub,
    ) async {
      final repo = _MockProfileRepo();
      when(() => repo.getMyProfile()).thenAnswer((_) async => stub());

      final container = ProviderContainer(overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        authStateChangesProvider.overrideWith((ref) => Stream.value('u1')),
      ]);
      addTearDown(container.dispose);
      container.listen(myProfileProvider, (_, __) {}, fireImmediately: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return container.read(myProfileProvider);
    }

    test('surfaces a repository Failure as AsyncError (not a raw throw)',
        () async {
      final v =
          await settledProfile(() => failure<MyProfile?>(const NetworkFailure()));
      expect(v.hasError, isTrue);
      expect(v.error, isA<NetworkFailure>());
    });

    test('returns the profile on success', () async {
      final me = profile(approved: true, withCity: city);
      final v = await settledProfile(() => success<MyProfile?>(me));
      expect(v.hasError, isFalse);
      expect(v.value?.profile.isVolunteer, isTrue);
    });
  });
}
