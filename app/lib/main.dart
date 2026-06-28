import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/firebase_init.dart';
import 'presentation/providers/core_providers.dart';

/// Background/terminated FCM handler. The system tray renders notification
/// payloads automatically; this exists so background data messages are handled.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op for now (no background data processing needed in M3).
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase. If firebase_options.dart is still the placeholder
  // (flutterfire configure not run yet), this throws and we boot into the
  // "not configured" screen instead of crashing.
  bool firebaseReady;
  try {
    await FirebaseBootstrap.initialize();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
