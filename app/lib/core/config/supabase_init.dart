import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Initializes the Supabase SDK. Call once during app startup before
/// `runApp`. Uses the public URL + anon (publishable) key from [Env].
class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // Supports the modern `sb_publishable_...` key format.
      publishableKey: Env.supabaseAnonKey,
      // Persist the session so the user stays logged in across restarts.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// The shared, authenticated Supabase client.
  static SupabaseClient get client => Supabase.instance.client;
}
