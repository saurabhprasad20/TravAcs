import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_request_repository.dart';
import '../../domain/entities/request.dart';
import '../../domain/repositories/request_repository.dart';
import 'core_providers.dart';
import 'profile_providers.dart';

final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  return FirestoreRequestRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

/// Live list of the signed-in requester's own requests.
final myRequestsProvider = StreamProvider<List<Request>>((ref) {
  return ref.watch(requestRepositoryProvider).watchMyRequests();
});

/// Live list of open requests in the TravAcser's city. Empty unless the
/// volunteer is approved and has a city set.
final availableRequestsProvider = StreamProvider<List<Request>>((ref) {
  final my = ref.watch(myProfileProvider).value;
  final city = my?.profile.serviceCity;
  final approved = my?.volunteer?.isApproved ?? false;
  if (city == null || !approved) return Stream.value(const []);
  return ref.watch(requestRepositoryProvider).watchAvailableRequests(city);
});
