import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_request_repository.dart';
import '../../domain/entities/assignment.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/request.dart';
import '../../domain/repositories/request_repository.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'profile_providers.dart';

/// Cloud Functions client, pinned to the function region.
final functionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instanceFor(region: 'asia-south2'),
);

final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  return FirestoreRequestRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
    ref.watch(functionsProvider),
  );
});

/// Live list of the signed-in requester's own requests.
final myRequestsProvider = StreamProvider<List<Request>>((ref) {
  // Rebuild when auth resolves (sign-in / sign-out); otherwise a stream built
  // before the uid is available stays permanently empty until an app restart.
  ref.watch(authStateChangesProvider);
  return ref.watch(requestRepositoryProvider).watchMyRequests();
});

/// The signed-in TravAcser's assignments (their accepted trips), newest first.
final myAssignmentsProvider = StreamProvider<List<Assignment>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(requestRepositoryProvider).watchMyAssignments();
});

/// Open requests in the TravAcser's city, EXCLUDING ones they already accepted.
/// Empty unless the volunteer is approved and has a city set.
final availableRequestsProvider = StreamProvider<List<Request>>((ref) {
  final my = ref.watch(myProfileProvider).value;
  final city = my?.profile.serviceCity;
  final approved = my?.volunteer?.isApproved ?? false;
  if (city == null || !approved) return Stream.value(const []);
  // The TravAcser's own gender, used to hide same-gender-restricted requests
  // that aren't theirs (until such a request widens to all genders).
  final myGender = my?.profile.gender;

  // Only ACTIVE assignments hide a request from the Available list. If the
  // TravAcser later cancels their slot, the (now cancelled) assignment must NOT
  // keep hiding the request — the server reopens it to broadcast, so it should
  // reappear here for everyone, including the TravAcser who cancelled.
  final acceptedIds = ref
          .watch(myAssignmentsProvider)
          .value
          ?.where((a) => a.isActive)
          .map((a) => a.requestId)
          .toSet() ??
      const <String>{};

  // Hide only requests that can no longer be accepted — i.e. past their
  // scheduled start (the server auto-cancels those). Short-notice trips stay on
  // the feed right up to their start time. Watch the clock so this advances even
  // without a new Firestore event.
  ref.watch(clockProvider);
  final now = DateTime.now();

  return ref
      .watch(requestRepositoryProvider)
      .watchAvailableRequests(city)
      .map((list) => list
          .where((r) =>
              !acceptedIds.contains(r.id) &&
              r.scheduledStartAt.isAfter(now) &&
              // Same-gender-restricted requests are hidden from other-gender
              // TravAcsers until they widen to all genders.
              (!r.genderRestricted ||
                  r.genderWidened ||
                  r.requesterGender == myGender))
          .toList());
});

/// TravAcsers who have accepted a given request (requester's view).
final requestAssignmentsProvider =
    StreamProvider.family<List<Assignment>, String>((ref, requestId) {
  return ref.watch(requestRepositoryProvider).watchRequestAssignments(requestId);
});

/// The requester's completed-but-unpaid trips ("pending dues"). A User must
/// clear these before creating a new request. Payment is per-trip, so this reads
/// the requester's own requests. Only trips that carry a trip-level bill
/// (`tripAmountInr > 0`, i.e. completed under the trip-level payment model) can
/// be dues — a legacy completed trip with no trip total is not blockable/payable
/// in-app, so it must not soft-lock the User out of creating new requests.
final myPendingDuesProvider = Provider<List<Request>>((ref) {
  final all = ref.watch(myRequestsProvider).value ?? const [];
  return all
      .where((r) =>
          r.status == RequestStatus.completed &&
          (r.tripAmountInr ?? 0) > 0 &&
          !r.isPaid)
      .toList();
});
