import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../core/util/scheduled_time.dart';
import '../../../domain/entities/assignment.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/request.dart';
import '../../providers/core_providers.dart';
import '../../providers/request_providers.dart';
import '../menu/info_screens.dart';
import '../shared/request_card.dart';
import '../shared/trip_payment.dart';
import 'request_controller.dart';

/// The requester's ACTIVE requests (scheduled / in progress) as a clean,
/// list-wise view. Each row is a compact summary (date, status, start code if
/// accepted); tapping opens a full-screen, scrollable [RequestDetailScreen]
/// where each label is individually readable and the Cancel / Reschedule / End
/// actions live. Completed trips move to Trip History.
class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);

    return Scaffold(
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(failureMessage(e))),
        data: (all) {
          final list = all.where((r) => isActiveRequest(r.status)).toList();
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No active requests. Create one from the Request tab.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) =>
                _RequestSummaryTile(request: list[i]),
          );
        },
      ),
    );
  }
}

/// Whether a request is still "active" (shown on My Requests rather than
/// Trip History).
bool isActiveRequest(RequestStatus s) =>
    s != RequestStatus.completed &&
    s != RequestStatus.closed &&
    s != RequestStatus.cancelled;

/// Whether a request can still be rescheduled: it hasn't truly started (a trip
/// only starts once a TravAcser accepted AND it was started), so an unaccepted
/// request stays reschedulable even past its time.
bool _rescheduleAllowed(Request r) =>
    r.acceptedCount == 0 || DateTime.now().isBefore(r.scheduledStartAt);

/// Compact, tappable summary row for one active request: date + time, status,
/// and the start code (once a TravAcser has accepted). Opens the full detail
/// page. The whole tile is one screen-reader node with an explicit summary.
class _RequestSummaryTile extends ConsumerWidget {
  const _RequestSummaryTile({required this.request});
  final Request request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final date = DateFormat.yMMMEd().format(r.scheduledDate);
    final time = formatTime12h(r.startTime);

    // Derive a compact code/status line only when a TravAcser has accepted.
    ({String visual, String semantic})? code;
    if (r.acceptedCount > 0) {
      code = _codeSummary(ref);
    }

    final semantic = 'Trip on $date at $time, status ${r.status.label}'
        '${code != null ? ', ${code.semantic}' : ''}. '
        'Double tap to view details.';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: semantic,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RequestDetailScreen(requestId: r.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$date · $time',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      RequestStatusChip(status: r.status),
                      if (code != null) ...[
                        const SizedBox(height: 6),
                        Text(code.visual,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A short code/status summary across the request's active assignments.
  ({String visual, String semantic}) _codeSummary(WidgetRef ref) {
    final async = ref.watch(requestAssignmentsProvider(request.id));
    final active =
        async.value?.where((a) => a.isActive).toList() ?? const [];
    if (active.isEmpty) {
      return (visual: 'TravAcser assigned', semantic: 'a TravAcser is assigned');
    }
    if (active.any((a) => a.tripStatus == TripStatus.started)) {
      return (visual: 'In progress', semantic: 'trip in progress');
    }
    if (active.length == 1) {
      final spaced = A11y.spellDigits(active.first.startOtp);
      return (
        visual: 'Start code: ${active.first.startOtp}',
        semantic: 'start code $spaced',
      );
    }
    return (
      visual: 'Start codes ready — open to view',
      semantic: 'start codes ready, open to view',
    );
  }
}

/// Full-screen, scrollable detail for one active request. Each field is an
/// individual screen-reader node; the start code, and Cancel / Reschedule / End
/// trip actions all live inside. Stays live off [myRequestsProvider].
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRequestsProvider);
    // Refresh time-derived bits (reschedule availability) without an event.
    ref.watch(clockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip details')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(failureMessage(e))),
        data: (all) {
          Request? r;
          for (final x in all) {
            if (x.id == requestId) {
              r = x;
              break;
            }
          }
          if (r == null || !isActiveRequest(r.status)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('This trip is no longer active.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _DetailBody(request: r);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.request});
  final Request request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final date = DateFormat.yMMMEd().format(r.scheduledDate);
    final time = formatTime12h(r.startTime);
    // A trip that has started (a TravAcser validated the start code) can only be
    // ended — never cancelled or rescheduled. The request doc's own status does
    // not change on start, so we key off the assignments.
    final anyStarted = ref
            .watch(requestAssignmentsProvider(r.id))
            .value
            ?.any((a) => a.isActive && a.tripStatus == TripStatus.started) ??
        false;
    final canReschedule = !anyStarted && _rescheduleAllowed(r);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: RequestStatusChip(status: r.status),
        ),
        const SizedBox(height: 12),
        _detailRow(context, Icons.schedule, 'Trip time', '$date, $time'),
        _detailRow(
            context, Icons.my_location, 'Pick-up location', r.meetingPoint),
        _detailRow(context, Icons.place_outlined, 'Destination', r.destination),
        _detailRow(
            context, Icons.group_outlined, 'Users travelling', '${r.numTravellers}'),
        _detailRow(context, Icons.volunteer_activism_outlined,
            'TravAcsers required', '${r.acceptedCount}/${r.numTravAcsers} filled'),
        _detailRow(context, Icons.wc_outlined, 'TravAcser preference',
            r.genderPreference.label),
        if (r.purpose != null && r.purpose!.isNotEmpty)
          _detailRow(context, Icons.info_outline, 'Purpose', r.purpose!),
        if (r.specialNote != null && r.specialNote!.isNotEmpty)
          _detailRow(context, Icons.sticky_note_2_outlined, 'Note', r.specialNote!),
        _detailRow(context, Icons.currency_rupee, 'Estimated amount',
            '₹${r.estimatedAmountInr}  (${r.estimateBreakdown})'),
        if (r.acceptedCount > 0) ...[
          const Divider(height: 28),
          Text('Your TravAcser${r.acceptedCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          _RequestAssignments(requestId: r.id),
        ],
        const SizedBox(height: 20),
        if (anyStarted)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'This trip has started — it can no longer be cancelled or '
              'rescheduled. End it from your TravAcser above when you finish.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.help_outline, semanticLabel: 'Get help'),
              label: const Text('Get help'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ContactUsScreen()),
              ),
            ),
            if (canReschedule)
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: const Text('Reschedule'),
                onPressed: () => _reschedule(context, ref, r),
              ),
            if (!anyStarted)
              OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel trip'),
                onPressed: () => _cancel(context, ref, r),
              ),
          ],
        ),
      ],
    );
  }

  /// A single labelled detail line as its OWN semantic node, so a screen-reader
  /// user lands on each field individually (unlike the merged summary card).
  Widget _detailRow(
      BuildContext context, IconData icon, String label, String value) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                        text: '$label: ',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: value),
                  ],
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref, Request r) async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    // Rescheduling is limited to Today / Tomorrow / Day after — anything beyond
    // that, the User is advised to create a new trip instead.
    final options = <String, DateTime>{
      'Today': today,
      'Tomorrow': today.add(const Duration(days: 1)),
      'Day after': today.add(const Duration(days: 2)),
    };
    final date = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('New trip day'),
        children: [
          for (final e in options.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.value),
              child: Semantics(
                button: true,
                label: '${e.key}, ${DateFormat.yMMMEd().format(e.value)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('${e.key} · ${DateFormat.yMMMEd().format(e.value)}'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              'To move a trip further out, cancel it and create a new one.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'New start time',
    );
    if (time == null || !context.mounted) return;
    final startTime =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .reschedule(r.id, DateUtils.dateOnly(date), startTime);
    if (!context.mounted) return;
    ok ? A11y.announce(context, 'Trip rescheduled.') : _err(context, ref);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Request r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this trip?'),
        content: const Text(
            'This withdraws the request. Any assigned TravAcsers are notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel trip')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    // Before anyone accepts we can cancel client-side; afterwards the server
    // function cancels the request + notifies the assigned TravAcsers.
    final notifier = ref.read(requestControllerProvider.notifier);
    final ok = r.acceptedCount == 0 && r.status.isCancellable
        ? await notifier.cancel(r.id)
        : await notifier.cancelTrip(r.id);
    if (!context.mounted) return;
    if (ok) {
      A11y.announce(context, 'Trip cancelled.');
      Navigator.of(context).maybePop(); // back to the list
    } else {
      _err(context, ref);
    }
  }

  void _err(BuildContext context, WidgetRef ref) {
    final msg = failureMessage(ref.read(requestControllerProvider).error);
    A11y.announce(context, msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Inline list of the TravAcsers assigned to a request. During the start
/// window the User's start code is shown here to read to their TravAcser.
class _RequestAssignments extends ConsumerWidget {
  const _RequestAssignments({required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(requestAssignmentsProvider(requestId));
    return assignments.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(failureMessage(e)),
      ),
      data: (list) {
        final active = list.where((a) => a.isActive).toList();
        if (active.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final a in active)
              _AssignmentTile(requestId: requestId, a: a),
          ],
        );
      },
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
    // Refresh on the clock so "Ready to start"/"In progress" advance with time.
    ref.watch(clockProvider);
    final now = DateTime.now();
    final inProgress = a.isInProgress(now);
    final awaitingStart = a.awaitingStart(now);
    // A started trip can only be ended at/after its scheduled start time.
    final canEnd = inProgress && !now.isBefore(a.effectiveStartAt);
    final statusText = inProgress
        ? 'In progress'
        : awaitingStart
            ? 'Ready to start'
            : 'Scheduled';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'TravAcser ${a.volunteerName}, phone '
                  '${a.volunteerPhone ?? 'not available'}, status $statusText',
              excludeSemantics: true,
              child: Row(
                children: [
                  const Icon(Icons.directions_walk, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.volunteerName,
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(a.volunteerPhone ?? 'Phone not available',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text(statusText,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (inProgress) ...[
              const SizedBox(height: 8),
              if (!canEnd)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'The trip has started. You can end it once its scheduled '
                    'start time (${DateFormat.jm().format(a.effectiveStartAt)}) '
                    'arrives.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('End trip & pay'),
                  onPressed: (busy || !canEnd) ? null : () => _end(context, ref),
                ),
              ),
            ] else ...[
              // Accepted but not yet started: show the start code straight away
              // so the User has it ready to read to their TravAcser. (Before any
              // TravAcser accepts there is no assignment/tile, hence no code.)
              if (!awaitingStart)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'Starts at ${DateFormat.jm().format(a.effectiveStartAt)}.',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              _StartCodeDisplay(otp: a.startOtp),
            ],
          ],
        ),
      ),
    );
  }

  /// User-side start code: shown large and read digit-by-digit so the User can
  /// tell it to their TravAcser, who enters it to begin the trip.

  Future<void> _end(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .completeTrip(requestId, a.volunteerId);
    if (!context.mounted) return;
    if (!ok) {
      _err(context, ref);
      return;
    }
    A11y.announce(context, 'Trip ended. Continue to payment.');
    // Chain straight into the Razorpay payment for this trip.
    await startTripPayment(
      context,
      ref,
      requestId: requestId,
      volunteerId: a.volunteerId,
      contact: a.requesterPhone,
    );
  }

  void _err(BuildContext context, WidgetRef ref) {
    final msg = failureMessage(ref.read(requestControllerProvider).error);
    A11y.announce(context, msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// The User's start code, shown large. Read digit-by-digit for screen-reader
/// users (golden rule) so the User can tell it to their TravAcser, who enters
/// it on their device to begin the trip.
class _StartCodeDisplay extends StatelessWidget {
  const _StartCodeDisplay({required this.otp});
  final String otp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spaced = otp.split('').join(' '); // "1 2 3 4" reads digit-by-digit
    return Semantics(
      label: 'Your start code: $spaced. '
          'Read it to your TravAcser to begin the trip.',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your start code',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 2),
            Text(
              spaced,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
            ),
            const SizedBox(height: 4),
            Text('Read this code to your TravAcser to begin the trip.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}
