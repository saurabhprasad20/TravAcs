import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/request.dart';
import '../../providers/profile_providers.dart';
import '../../providers/request_providers.dart';
import '../requester/request_controller.dart';
import '../shared/request_card.dart';

/// TravAcser's live list of open requests in their city, with Accept.
class AvailableRequestsScreen extends ConsumerWidget {
  const AvailableRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final my = ref.watch(myProfileProvider).value;
    final approved = my?.volunteer?.isApproved ?? false;
    final hasCity = my?.profile.serviceCity != null;

    return Scaffold(
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
        child: Text(failureMessage(e)),
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
            actions: [_AcceptButton(request: list[i])],
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

class _AcceptButton extends ConsumerWidget {
  const _AcceptButton({required this.request});
  final Request request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(requestControllerProvider).isLoading;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${request.acceptedCount}/${request.numTravAcsers} filled'),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: busy ? null : () => _accept(context, ref),
          child: const Text('Accept'),
        ),
      ],
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final ok =
        await ref.read(requestControllerProvider.notifier).accept(request.id);
    if (!context.mounted) return;
    if (ok) {
      A11y.announce(context, 'Accepted. See it under My Trips.');
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Request accepted.')));
    } else {
      final msg = failureMessage(ref.read(requestControllerProvider).error);
      A11y.announce(context, msg);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
