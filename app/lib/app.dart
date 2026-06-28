import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/core_providers.dart';

/// Root application widget. Uses `MaterialApp.router` wired to the
/// Riverpod-provided [routerProvider].
class TravAcsApp extends ConsumerWidget {
  const TravAcsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(firebaseReadyProvider)) {
      return const _NotConfiguredApp();
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      // Respect the user's enlarged system font, but cap it so the fixed
      // layouts never clip or overlap. We never shrink below 1.0 (M9, §11).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.8,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Shown when Firebase failed to initialize — almost always because
/// `flutterfire configure` hasn't been run to generate firebase_options.dart.
class _NotConfiguredApp extends StatelessWidget {
  const _NotConfiguredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Firebase is not configured.\n\n'
              'Run:\n'
              '  flutterfire configure\n\n'
              'to generate lib/firebase_options.dart for your project.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}
