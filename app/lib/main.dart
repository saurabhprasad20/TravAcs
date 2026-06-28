import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/firebase_init.dart';
import 'presentation/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase. If firebase_options.dart is still the placeholder
  // (flutterfire configure not run yet), this throws and we boot into the
  // "not configured" screen instead of crashing.
  bool firebaseReady;
  try {
    await FirebaseBootstrap.initialize();
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }

  runApp(
    ProviderScope(
      overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
      child: const TravAcsApp(),
    ),
  );
}
