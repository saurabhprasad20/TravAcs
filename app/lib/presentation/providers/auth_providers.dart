import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import 'core_providers.dart';

/// Provides the [AuthRepository] implementation. Overridable in tests.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
});

/// Streams the current uid (null = signed out). The router and profile
/// provider listen to this to react to sign-in / sign-out.
final authStateChangesProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);
