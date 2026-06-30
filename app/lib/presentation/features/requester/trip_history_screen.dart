import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/assignment.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/request.dart';
import '../../providers/request_providers.dart';
import '../shared/rating_sheet.dart';
import 'request_controller.dart';

/// The requester's completed/closed/cancelled requests (Trip History tab).
/// Mark-as-Paid + Rate live here, per assigned TravAcser (M12).
class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);

    return Scaffold(
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(failureMessage(e))),
        data: (all) {
          final list = all.where((r) => _isTerminal(r.status)).toList();
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No trips yet.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) => _HistoryCard(r: list[i]),
          );
        },
      ),
    );
  }

  static bool _isTerminal(RequestStatus s) =>
      s == RequestStatus.completed ||
      s == RequestStatus.closed ||
      s == RequestStatus.cancelled;
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.r});
  final Request r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when = DateFormat.yMMMEd().format(r.scheduledDate);
    final cancelled = r.status == RequestStatus.cancelled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$when · ${r.destination}',
                style: Theme.of(context).textTheme.titleMedium),
            Text(cancelled ? 'Cancelled' : 'Completed',
                style: Theme.of(context).textTheme.bodySmall),
            if (!cancelled) _Assignments(requestId: r.id),
          ],
        ),
      ),
    );
  }
}

class _Assignments extends ConsumerWidget {
  const _Assignments({required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(requestAssignmentsProvider(requestId));
    return assignments.maybeWhen(
      data: (list) {
        final done = list
            .where((a) =>
                a.tripStatus == TripStatus.completed ||
                a.tripStatus == TripStatus.closed)
            .toList();
        if (done.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            for (final a in done) _AssignmentRow(requestId: requestId, a: a),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _AssignmentRow extends ConsumerWidget {
  const _AssignmentRow({required this.requestId, required this.a});
  final String requestId;
  final Assignment a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(requestControllerProvider).isLoading;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${a.volunteerName} · ₹${a.amountInr ?? 0} · '
              '${a.paymentStatus.label}'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (a.requesterPaidAt == null)
                OutlinedButton(
                  onPressed: busy ? null : () => _pay(context, ref),
                  child: const Text('Mark as Paid'),
                ),
              if (a.ratedByRequester)
                Text('You rated ${a.requesterRatingStars}★')
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.star_border),
                  label: const Text('Rate TravAcser'),
                  onPressed: busy ? null : () => _rate(context, ref),
                ),
            ],
          ),
        ],
      ),
    );
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
