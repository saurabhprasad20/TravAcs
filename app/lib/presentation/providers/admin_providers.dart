import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_admin_repository.dart';
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

/// Live list of all active trips across the platform, for the admin monitoring
/// dashboard (admin only; enforced by Security Rules).
final activeTripsProvider = StreamProvider<List<Request>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(requestRepositoryProvider).watchActiveTrips();
});
