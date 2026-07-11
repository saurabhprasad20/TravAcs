import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_request_repository.dart';
import '../../domain/entities/assignment.dart';
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

  // Hide requests that can no longer realistically be accepted: within 30 min
  // of (or past) their scheduled start they "disappear" from the feed (item 2).
  // The server separately warns the User and auto-cancels at the start time.
  // Watch the clock so the cutoff advances even without a new Firestore event.
  ref.watch(clockProvider);
  final cutoff = DateTime.now().add(const Duration(minutes: 30));

  return ref
      .watch(requestRepositoryProvider)
      .watchAvailableRequests(city)
      .map((list) => list
          .where((r) =>
              !acceptedIds.contains(r.id) && r.scheduledStartAt.isAfter(cutoff))
          .toList());
});

/// TravAcsers who have accepted a given request (requester's view).
final requestAssignmentsProvider =
    StreamProvider.family<List<Assignment>, String>((ref, requestId) {
  return ref.watch(requestRepositoryProvider).watchRequestAssignments(requestId);
});
