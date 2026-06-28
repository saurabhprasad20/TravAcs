import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../providers/profile_providers.dart';
import '../../providers/request_providers.dart';
import '../shared/request_card.dart';

/// TravAcser's live list of open requests in their city. (Accept arrives in M4.)
class AvailableRequestsScreen extends ConsumerWidget {
  const AvailableRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final my = ref.watch(myProfileProvider).value;
    final approved = my?.volunteer?.isApproved ?? false;
    final hasCity = my?.profile.serviceCity != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Available Requests')),
      body: !approved
          ? _message(context,
              'Your account is pending verification. Once an admin approves you, '
              'requests in your city will appear here.')
          : !hasCity
              ? _message(context,
                  'Set your service area (state & city) on the Profile tab to see '
                  'requests.')
              : _list(context, ref),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(availableRequestsProvider);
    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(e is Failure ? e.message : 'Could not load requests.'),
      ),
      data: (list) {
        if (list.isEmpty) {
          return _message(context,
              'No open requests in your city right now. You will be notified '
              'when a new one is posted.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, i) => RequestCard(
            request: list[i],
            actions: const [
              // Accept is implemented in M4 (FCFS).
              Text('Accept coming soon'),
            ],
          ),
        );
      },
    );
  }

  Widget _message(BuildContext context, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
}
