import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../providers/request_providers.dart';
import '../shared/request_card.dart';
import 'request_controller.dart';

/// The requester's live list of their own requests.
class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is Failure ? e.message : 'Could not load requests.'),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No requests yet. Create one from the Request tab.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return RequestCard(
                request: r,
                actions: [
                  if (r.status.isCancellable)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                      onPressed: () => _cancel(context, ref, r.id),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text('This will withdraw your request.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel request')),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await ref.read(requestControllerProvider.notifier).cancel(id);
    if (ok && context.mounted) A11y.announce(context, 'Request cancelled.');
  }
}
