import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/firebase_init.dart';
import 'core/error/error_fallback.dart';
import 'core/error/error_reporter.dart';
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

  // Global error boundary: uncaught errors are logged (Crashlytics) and never
  // shown raw to the user.
  FlutterError.onError = (details) {
    ErrorReporter.reportFatal(details.exception, details.stack, fatal: false);
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.reportFatal(error, stack);
    return true;
  };
  // Replace the default red/grey error widget with a calm fallback (release).
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const ErrorFallback();
  }

  runApp(
    ProviderScope(
      overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
      child: const TravAcsApp(),
    ),
  );
}
