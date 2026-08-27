import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/messaging_providers.dart';
import '../../providers/profile_providers.dart';
import '../auth/auth_controller.dart';

class AccountSuspendedScreen extends ConsumerWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value?.profile;
    final liveBan = ref.watch(myAccountBanProvider).value;
    final until = liveBan?.bannedUntil ?? profile?.bannedUntil;
    final reason = liveBan?.reason ?? profile?.banReason;
    return Scaffold(
      appBar: AppBar(title: const Text('Account temporarily suspended')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 56, semanticLabel: 'Suspended'),
                const SizedBox(height: 16),
                Text(
                  'You cannot use TravAcs while this temporary suspension is '
                  'active.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (until != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Access resumes after ${DateFormat.yMMMd().add_jm().format(until)}.',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (reason?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text('Reason: $reason', textAlign: TextAlign.center),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Contact TravAcs support if you believe this is a mistake.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
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
          ),
        ),
      ),
    );
  }
}
