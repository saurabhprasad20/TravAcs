import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_messaging_repository.dart';
import 'core_providers.dart';

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

final messagingRepositoryProvider = Provider<FirebaseMessagingRepository>((ref) {
  return FirebaseMessagingRepository(
    ref.watch(firebaseMessagingProvider),
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});
