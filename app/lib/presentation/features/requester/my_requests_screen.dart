import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/assignment.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/request.dart';
import '../../providers/core_providers.dart';
import '../../providers/request_providers.dart';
import '../shared/request_card.dart';
import '../shared/trip_payment.dart';
import 'request_controller.dart';

/// The requester's ACTIVE requests (scheduled / in progress). Completed trips
/// move to Trip History. A trip starts when the TravAcser validates the User's
/// start code; the User can reschedule (before start) or cancel, and either
/// party can end a started trip.
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
          final list = all.where((r) => _isActive(r.status)).toList();
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
            itemBuilder: (context, i) {
              final r = list[i];
              // A trip has only "started" once it is BOTH accepted (a TravAcser
              // took it) AND its scheduled time has arrived. An unaccepted
              // request never starts on time alone, so it stays reschedulable.
              final notStarted = r.acceptedCount == 0 ||
                  DateTime.now().isBefore(r.scheduledStartAt);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RequestCard(
                    request: r,
                    actions: [
                      if (notStarted)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.schedule),
                          label: const Text('Reschedule'),
                          onPressed: () => _reschedule(context, ref, r),
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                        onPressed: () => _cancel(context, ref, r),
                      ),
                    ],
                  ),
                  if (r.acceptedCount > 0)
                    _RequestAssignments(requestId: r.id),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static bool _isActive(RequestStatus s) =>
      s != RequestStatus.completed &&
      s != RequestStatus.closed &&
      s != RequestStatus.cancelled;

  Future<void> _reschedule(BuildContext context, WidgetRef ref, Request r) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: r.scheduledDate.isBefore(now) ? now : r.scheduledDate,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'New trip date',
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
    ok
        ? A11y.announce(context, 'Trip rescheduled.')
        : _err(context, ref);
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
    ok ? A11y.announce(context, 'Trip cancelled.') : _err(context, ref);
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
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('End trip & pay'),
                  onPressed: busy ? null : () => _end(context, ref),
                ),
              ),
            ] else if (awaitingStart)
              _StartCodeDisplay(otp: a.startOtp)
            else
              Text('Starts at ${DateFormat.jm().format(a.effectiveStartAt)} — '
                  'share your start code with your TravAcser when you meet.',
                  style: Theme.of(context).textTheme.bodySmall),
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
