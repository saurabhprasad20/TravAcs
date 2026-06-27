import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_profile_repository.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'core_providers.dart';

/// Provides the [ProfileRepository] implementation.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's profile (or null if registration is incomplete).
/// Re-fetches on auth changes; `invalidate` after saving a profile to refresh
/// the router (so it moves from complete-profile into the role shell).
final myProfileProvider = FutureProvider<MyProfile?>((ref) async {
  // Rebuild when auth state changes (sign-in / sign-out / token refresh).
  ref.watch(authStateChangesProvider);
  final result = await ref.watch(profileRepositoryProvider).getMyProfile();
  return result.match((failure) => throw failure, (profile) => profile);
});
