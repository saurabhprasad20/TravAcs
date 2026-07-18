import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/assignment.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/request.dart';
import '../../providers/request_providers.dart';
import '../menu/info_screens.dart';
import '../shared/history_controls.dart';
import '../shared/rating_sheet.dart';
import '../shared/trip_payment.dart';
import 'request_controller.dart';

/// The requester's completed/closed/cancelled requests (Trip History tab). One
/// trip total + a single "Make payment" (whole trip) live here, plus a per-
/// TravAcser breakdown and rating. Ordered newest first, filterable, and capped
/// at the most recent [kHistoryPageSize] trips.
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
    ref.listen(myRequestsProvider, (prev, next) {
      if (next.hasError && (prev == null || !prev.hasError)) {
        A11y.announce(context, failureMessage(next.error));
      }
    });
    final requests = ref.watch(myRequestsProvider);

    return Scaffold(
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(failureMessage(e))),
        data: (all) {
          var list = all.where((r) => _isTerminal(r.status)).toList();
          list = list.where((r) => _matchesFilter(r.status)).toList();
          // Sort by creation time (fall back to scheduled date for legacy docs
          // without a createdAt).
          DateTime key(Request r) => r.createdAt ?? r.scheduledDate;
          list.sort((a, b) => _sort == HistorySort.newest
              ? key(b).compareTo(key(a))
              : key(a).compareTo(key(b)));
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
                        itemBuilder: (context, i) => _HistoryCard(r: shown[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesFilter(RequestStatus s) => switch (_filter) {
        HistoryFilter.all => true,
        HistoryFilter.completed =>
          s == RequestStatus.completed || s == RequestStatus.closed,
        HistoryFilter.cancelled => s == RequestStatus.cancelled,
      };

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
    final busy = ref.watch(requestControllerProvider).isLoading;
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
            if (!cancelled) ...[
              const SizedBox(height: 4),
              // One total for the whole trip (all TravAcsers). The User pays once
              // to the app; the admin team distributes each share manually.
              Semantics(
                label: 'Trip total ₹${r.tripAmountInr ?? 0}, '
                    '${r.isPaid ? 'paid' : 'payment pending'}',
                excludeSemantics: true,
                child: Text(
                  'Trip total: ₹${r.tripAmountInr ?? 0} · '
                  '${r.isPaid ? 'Paid' : 'Payment pending'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              // Per-TravAcser breakdown + rating (no per-TravAcser payment).
              _Assignments(requestId: r.id),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.help_outline,
                        semanticLabel: 'Get help'),
                    label: const Text('Get help'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const ContactUsScreen()),
                    ),
                  ),
                  if (!r.isPaid && (r.tripAmountInr ?? 0) > 0)
                    FilledButton.icon(
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Make payment'),
                      onPressed: busy ? null : () => _pay(context, ref),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    await startTripPayment(context, ref, requestId: r.id);
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
    // A `closed` assignment never started (e.g. a second TravAcser on a trip
    // another TravAcser ended) — there is no charge and nothing to pay/rate.
    final noCharge =
        a.tripStatus == TripStatus.closed || (a.amountInr ?? 0) <= 0;
    if (noCharge) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('${a.volunteerName} · Not started — no charge',
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${a.volunteerName} · ₹${a.amountInr ?? 0}'),
          Text('Breakdown: ${a.amountBreakdown}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
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
    );
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
