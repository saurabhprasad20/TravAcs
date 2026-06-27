import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_init.dart';

/// Exposes the shared [SupabaseClient] to the Riverpod graph. Overridable in
/// tests with a mock/fake client.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => SupabaseBootstrap.client,
);

/// Streams Supabase auth state changes (sign-in / sign-out / token refresh).
/// The router listens to this to redirect between auth, profile and shell.
final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);
