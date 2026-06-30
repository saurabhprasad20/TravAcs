import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/assignment.dart';
import '../../../domain/entities/enums.dart';
import '../../providers/request_providers.dart';
import '../requester/request_controller.dart';
import '../shared/rating_sheet.dart';

/// The TravAcser's completed/closed/cancelled trips (Trip History tab). Shows
/// total earnings and per-trip "Mark received" + "Rate the User" (M12).
class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(myAssignmentsProvider);

    return Scaffold(
      body: assignments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(failureMessage(e))),
        data: (all) {
          final list = all.where((a) => a.tripStatus.isTerminal).toList()
            ..sort((x, y) => y.scheduledDate.compareTo(x.scheduledDate));
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No trips yet.', textAlign: TextAlign.center),
              ),
            );
          }
          final totalEarned = list
              .where((a) => a.tripStatus != TripStatus.cancelled)
              .fold<int>(0, (sum, a) => sum + (a.amountInr ?? 0));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  title: const Text('Total earned'),
                  trailing: Text('₹$totalEarned',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              const SizedBox(height: 8),
              for (final a in list) _HistoryCard(a: a),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.a});
  final Assignment a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when = DateFormat.yMMMEd().format(a.scheduledDate);
    final busy = ref.watch(requestControllerProvider).isLoading;
    final cancelled = a.tripStatus == TripStatus.cancelled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$when · ${a.destination}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (cancelled)
                    const Text('Cancelled')
                  else
                    Text('${a.durationMinutes ?? 0} min · '
                        '₹${a.amountInr ?? 0} earned · ${a.paymentStatus.label}'),
                ],
              ),
            ),
            if (!cancelled) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (a.travAcserReceivedAt == null)
                    OutlinedButton(
                      onPressed: busy ? null : () => _markReceived(context, ref),
                      child: const Text('Mark received'),
                    ),
                  const SizedBox(width: 8),
                  if (a.ratedByVolunteer)
                    Text('You rated ${a.volunteerRatingStars}★')
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.star_border),
                      label: const Text('Rate the User'),
                      onPressed: busy ? null : () => _rate(context, ref),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markReceived(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .markReceived(a.requestId);
    if (!context.mounted) return;
    ok ? A11y.announce(context, 'Marked received.') : _error(context, ref);
  }

  Future<void> _rate(BuildContext context, WidgetRef ref) async {
    final result = await showRatingSheet(context, title: 'Rate the User');
    if (result == null || !context.mounted) return;
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .submitRating(a.requestId, a.volunteerId, result.$1, result.$2);
    if (!context.mounted) return;
    ok ? A11y.announce(context, 'Thanks for rating.') : _error(context, ref);
  }

  void _error(BuildContext context, WidgetRef ref) {
    final msg = failureMessage(ref.read(requestControllerProvider).error);
    A11y.announce(context, msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}
