import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import 'core_providers.dart';

/// Provides the [AuthRepository] implementation. Overridable in tests.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});
