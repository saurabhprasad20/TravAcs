import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import '../../providers/profile_providers.dart';

/// Shown while the user's profile is resolved after sign-in. The router
/// redirects away once the profile loads (to complete-profile or the shell).
/// On error (e.g. no network) it offers an accessible retry.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      body: Center(
        child: profile.when(
          loading: () => const _Loading(),
          // Redirect handles the data case; show a brief loader meanwhile.
          data: (_) => const _Loading(),
          error: (error, _) {
            final message = failureMessage(error);
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(myProfileProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading ${AppConstants.appName}',
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppConstants.appName, style: TextStyle(fontSize: 28)),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    );
  }
}
