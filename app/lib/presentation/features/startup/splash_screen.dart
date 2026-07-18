import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import '../../providers/auth_providers.dart';
import '../../providers/messaging_providers.dart';
import '../../providers/profile_providers.dart';
import '../auth/auth_controller.dart';

/// Shown while the user's profile is resolved after sign-in. The router
/// redirects away once the profile loads (to complete-profile or the shell).
/// On error (e.g. no network) it offers an accessible retry + a sign-out escape
/// so a failed profile/admin fetch can never soft-lock the app on the splash.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    // Announce the error once when the profile fetch fails.
    ref.listen(myProfileProvider, (_, next) {
      if (next.hasError) {
        A11y.announce(context, failureMessage(next.error));
      }
    });
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
                    onPressed: () {
                      // Re-fetch both gates the router depends on.
                      ref.invalidate(isAdminProvider);
                      ref.invalidate(myProfileProvider);
                    },
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(messagingRepositoryProvider)
                          .unregisterToken();
                      await ref.read(authControllerProvider.notifier).signOut();
                    },
                    child: const Text('Sign out'),
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
