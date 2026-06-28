import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/assignment.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/request.dart';
import '../../providers/request_providers.dart';
import '../shared/rating_sheet.dart';
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
          child: Text(failureMessage(e)),
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
                  if (r.acceptedCount > 0)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.group_outlined),
                      label: Text(
                          'TravAcsers ${r.acceptedCount}/${r.numTravAcsers}'),
                      onPressed: () => _showAssignments(context, r),
                    ),
                  // Cancel only while no one has accepted yet.
                  if (r.status.isCancellable && r.acceptedCount == 0)
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

  void _showAssignments(BuildContext context, Request r) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AssignmentsSheet(requestId: r.id),
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

/// Lists the TravAcsers who accepted, with each one's contact + OTP to share.
class _AssignmentsSheet extends ConsumerWidget {
  const _AssignmentsSheet({required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(requestAssignmentsProvider(requestId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: assignments.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(failureMessage(e)),
          ),
          data: (list) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your TravAcsers',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                  'Share each TravAcser\'s code with them in person — they enter '
                  'it to start the trip.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              for (final a in list)
                _AssignmentTile(requestId: requestId, a: a),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final total = list
                    .where((a) => a.amountInr != null)
                    .fold<int>(0, (s, a) => s + (a.amountInr ?? 0));
                if (total == 0) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text('Total so far: ₹$total',
                      style: Theme.of(context).textTheme.titleMedium),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentTile extends ConsumerWidget {
  const _AssignmentTile({required this.requestId, required this.a});
  final String requestId;
  final Assignment a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(requestControllerProvider).isLoading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(a.volunteerName,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(a.tripStatus.label),
              ],
            ),
            Text(a.volunteerPhone ?? 'Phone not available',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ..._content(context, ref, busy),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, bool busy) {
    switch (a.tripStatus) {
      case TripStatus.assigned:
        return [
          Row(
            children: [
              const Text('Code to share: '),
              _OtpChip(requestId: requestId, volunteerId: a.volunteerId),
            ],
          ),
        ];
      case TripStatus.started:
        return [const Text('Trip in progress.')];
      case TripStatus.completed:
      case TripStatus.closed:
        return [
          Text('₹${a.amountInr ?? 0} · ${a.paymentStatus.label}',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (a.requesterPaidAt == null)
                OutlinedButton(
                  onPressed: busy ? null : () => _pay(context, ref),
                  child: const Text('Mark as Paid'),
                ),
              a.ratedByRequester
                  ? Text('You rated ${a.requesterRatingStars}★')
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.star_border),
                      label: const Text('Rate TravAcser'),
                      onPressed: busy ? null : () => _rate(context, ref),
                    ),
            ],
          ),
        ];
    }
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .markPaid(requestId, a.volunteerId);
    if (!context.mounted) return;
    ok ? A11y.announce(context, 'Marked as paid.') : _err(context, ref);
  }

  Future<void> _rate(BuildContext context, WidgetRef ref) async {
    final result =
        await showRatingSheet(context, title: 'Rate ${a.volunteerName}');
    if (result == null || !context.mounted) return;
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .submitRating(requestId, a.volunteerId, result.$1, result.$2);
    if (!context.mounted) return;
    ok ? A11y.announce(context, 'Thanks for rating.') : _err(context, ref);
  }

  void _err(BuildContext context, WidgetRef ref) {
    final msg = failureMessage(ref.read(requestControllerProvider).error);
    A11y.announce(context, msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _OtpChip extends ConsumerWidget {
  const _OtpChip({required this.requestId, required this.volunteerId});
  final String requestId;
  final String volunteerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otp = ref.watch(
        shareOtpProvider((requestId: requestId, volunteerId: volunteerId)));
    final code = otp.value;
    return Semantics(
      label: code == null
          ? 'Code loading'
          : 'Code ${A11y.spellDigits(code)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          code ?? '••••••',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
