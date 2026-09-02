import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import '../../providers/messaging_providers.dart';
import '../auth/auth_controller.dart';
import 'info_screens.dart';

/// The app-wide navigation menu (opened from the shell/admin AppBar hamburger).
/// Holds support/legal links + Sign out, with an explicit close (dismiss)
/// button in the header. Placeholder items are clearly marked.
class AppMenuDrawer extends ConsumerWidget {
  const AppMenuDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ---- header with the dismiss (close) button ----
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              color: scheme.primaryContainer,
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.accessibility_new,
                      size: 36,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: scheme.onPrimaryContainer),
                          ),
                          Text(
                            'Version ${AppConstants.appVersion}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, semanticLabel: 'Close menu'),
                    color: scheme.onPrimaryContainer,
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // ---- items ----
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _item(
                    context,
                    icon: Icons.support_agent_outlined,
                    label: 'Need help? Contact us',
                    onTap: () => _push(context, const ContactUsScreen()),
                  ),
                  _item(
                    context,
                    icon: Icons.info_outline,
                    label: 'About us',
                    onTap: () => _about(context),
                  ),
                  _item(
                    context,
                    icon: Icons.star_rate_outlined,
                    label: 'Rate us on Play Store',
                    onTap: () => _rate(context),
                  ),
                  _item(
                    context,
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => _push(context, const TermsScreen()),
                  ),
                  _item(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => _push(context, const PrivacyPolicyScreen()),
                  ),
                  const Divider(),
                  _item(
                    context,
                    icon: Icons.logout,
                    label: 'Sign out',
                    onTap: () => _signOut(context, ref),
                  ),
                  _item(
                    context,
                    icon: Icons.delete_forever_outlined,
                    label: 'Delete account',
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: ExcludeSemantics(child: Icon(icon)),
      title: Text(label),
      onTap: onTap,
    );
  }

  /// Closes the drawer, then pushes [screen] above the whole shell.
  void _push(BuildContext context, Widget screen) {
    final root = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop(); // dismiss the drawer
    root.push(MaterialPageRoute(builder: (_) => screen));
  }

  void _about(BuildContext context) {
    final root = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop();
    showAboutDialog(
      context: root.context,
      applicationName: AppConstants.appName,
      applicationVersion: 'Version ${AppConstants.appVersion}',
      applicationIcon: const Icon(Icons.accessibility_new, size: 40),
      children: const [
        SizedBox(height: 8),
        Text(
          'TravAcs connects visually-impaired Users with verified TravAcsers '
          'for paid, in-person travel assistance — for example getting from '
          'home to a metro station, a hospital or an office.',
        ),
        SizedBox(height: 12),
        Text(
          'Built accessibility-first: every screen is designed to work with a '
          'screen reader. Users request help, nearby verified TravAcsers accept, '
          'they meet and complete the trip, and the User pays a single fair '
          'amount for the whole trip.',
        ),
        SizedBox(height: 12),
        Text(
          'Made in India, for travellers across India. Visit '
          '${AppConstants.website}.',
        ),
      ],
    );
  }

  void _rate(BuildContext context) {
    final root = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop();
    showDialog<void>(
      context: root.context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Rate us'),
            content: const Text(
              'We’re not on the Play Store yet — you’ll be able to rate us there '
              'once we launch. In the meantime we’d love your feedback: email us '
              'at ${AppConstants.supportEmail} and tell us what’s working and '
              'what we can improve. Thank you for your support!',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              'You’ll need to verify your number again to sign '
              'back in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sign out'),
              ),
            ],
          ),
    );
    if (confirm != true || !context.mounted) return;
    A11y.announce(context, 'Signing out.');
    // Capture before the drawer/shell is torn down by the router redirect.
    final messaging = ref.read(messagingRepositoryProvider);
    final auth = ref.read(authControllerProvider.notifier);
    Navigator.of(context).pop(); // dismiss the drawer
    await messaging.unregisterToken();
    await auth.signOut(); // authStateChanges -> router redirects to /auth/phone
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete account?'),
            content: const Text(
              'Confirming will remove your user details and profile data from '
              'the app. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep account'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete account'),
              ),
            ],
          ),
    );
    if (confirm != true || !context.mounted) return;

    A11y.announce(context, 'Deleting account.');
    final auth = ref.read(authControllerProvider.notifier);
    final deleted = await auth.deleteAccount();
    if (!deleted && context.mounted) {
      final message = failureMessage(ref.read(authControllerProvider).error);
      A11y.announce(context, message);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
