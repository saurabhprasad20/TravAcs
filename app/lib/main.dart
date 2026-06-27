import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/config/supabase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize Supabase when configured, so the app can still boot into
  // the "misconfigured" screen (and `flutter build` succeeds) without creds.
  if (Env.isConfigured) {
    await SupabaseBootstrap.initialize();
  }

  runApp(const ProviderScope(child: TravAcsApp()));
}
