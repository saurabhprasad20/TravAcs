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

/// Whether the signed-in user is an admin (custom claim). Re-evaluated on auth
/// changes; the router uses it to route admins to the Admin screen.
final isAdminProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).isAdmin();
});
