import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_admin_repository.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/pending_volunteer.dart';
import '../../domain/entities/request.dart';
import '../../domain/repositories/admin_repository.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'request_providers.dart' show functionsProvider, requestRepositoryProvider;

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return FirestoreAdminRepository(
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
  );
});

/// Live list of TravAcsers awaiting verification (admin only).
final pendingVolunteersProvider =
    StreamProvider<List<PendingVolunteer>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingVolunteers();
});

/// Raw live stream of all active-STATUS trips (broadcast/assigned/started),
/// oldest scheduled first. Filtered by [activeTripsProvider] before display.
final _activeTripsRawProvider = StreamProvider<List<Request>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(requestRepositoryProvider).watchActiveTrips();
});

/// Active + upcoming trips for the admin monitoring dashboard. A trip that is
/// in progress (`started`) is always shown; a not-yet-started trip is shown
/// only while it is still upcoming (its scheduled start is in the future).
/// Past-dated trips that were never started (stale/overdue leftovers) are hidden
/// so the admin sees only live and upcoming work — not history. Re-filters on
/// the clock so a trip drops off once its start time passes.
final activeTripsProvider = Provider<AsyncValue<List<Request>>>((ref) {
  ref.watch(clockProvider);
  final now = DateTime.now();
  return ref.watch(_activeTripsRawProvider).whenData((list) => list
      .where((r) =>
          r.status == RequestStatus.started || r.scheduledStartAt.isAfter(now))
      .toList());
});
