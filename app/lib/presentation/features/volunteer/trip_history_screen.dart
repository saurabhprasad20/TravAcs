import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/assignment.dart';
import '../../../domain/entities/enums.dart';
import '../../providers/request_providers.dart';
import '../menu/info_screens.dart';
import '../requester/request_controller.dart';
import '../shared/history_controls.dart';
import '../shared/rating_sheet.dart';

/// The TravAcser's completed/closed/cancelled trips (Trip History tab). Shows
/// each trip's date/destination/duration, payment status (informational — the
/// User pays the app once per trip and the admin distributes shares), and a
/// per-trip "Rate the User". No earnings figures are shown. Ordered newest
/// first, filterable, and capped at the most recent [kHistoryPageSize].
class TripHistoryScreen extends ConsumerStatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  ConsumerState<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends ConsumerState<TripHistoryScreen> {
  HistoryFilter _filter = HistoryFilter.all;
  HistorySort _sort = HistorySort.newest;

  @override
  Widget build(BuildContext context) {
    ref.listen(myAssignmentsProvider, (prev, next) {
      if (next.hasError && (prev == null || !prev.hasError)) {
        A11y.announce(context, failureMessage(next.error));
      }
    });
    final assignments = ref.watch(myAssignmentsProvider);

    return Scaffold(
      body: assignments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(failureMessage(e))),
        data: (all) {
          final terminal =
              all.where((a) => a.tripStatus.isTerminal).toList();

          var list =
              terminal.where((a) => _matchesFilter(a.tripStatus)).toList();
          DateTime key(Assignment a) => a.acceptedAt ?? a.scheduledDate;
          list.sort((x, y) => _sort == HistorySort.newest
              ? key(y).compareTo(key(x))
              : key(x).compareTo(key(y)));
          final shown = list.take(kHistoryPageSize).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: HistoryControls(
                  filter: _filter,
                  sort: _sort,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  onSortChanged: (s) => setState(() => _sort = s),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No trips yet.',
                              textAlign: TextAlign.center),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: shown.length,
                        itemBuilder: (context, i) => _HistoryCard(a: shown[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesFilter(TripStatus s) => switch (_filter) {
        HistoryFilter.all => true,
        HistoryFilter.completed =>
          s == TripStatus.completed || s == TripStatus.closed,
        HistoryFilter.cancelled => s == TripStatus.cancelled,
      };
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
                  else ...[
                    Text('${a.durationMinutes ?? 0} min',
                        style: Theme.of(context).textTheme.bodySmall),
                    // Payment status is informational: the User pays the app once
                    // for the whole trip; each TravAcser's share is transferred by
                    // the admin team afterwards (no in-app "mark received" step).
                    Text('Payment: ${a.paymentStatus.label}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.help_outline, semanticLabel: 'Get help'),
                label: const Text('Get help'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const ContactUsScreen()),
                ),
              ),
            ),
            if (!cancelled) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
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
