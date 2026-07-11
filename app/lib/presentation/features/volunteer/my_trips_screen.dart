import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../core/util/scheduled_time.dart';
import '../../../domain/entities/assignment.dart';
import '../../providers/core_providers.dart';
import '../../providers/request_providers.dart';
import '../requester/request_controller.dart';

/// The TravAcser's ACTIVE trips (scheduled or in progress), live. Completed
/// trips move to the Trip History tab. Trips auto-start at their scheduled time
/// (no OTP); either party can end one (M12).
class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(myAssignmentsProvider);

    return Scaffold(
      body: assignments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(failureMessage(e))),
        data: (all) {
          final list = all.where((a) => a.isActive).toList();
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No active trips. Accept a request from the Available tab.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) => _TripCard(a: list[i]),
          );
        },
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  const _TripCard({required this.a});
  final Assignment a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat.yMMMEd().format(a.scheduledDate);
    final time = formatTime12h(a.startTime);
    final busy = ref.watch(requestControllerProvider).isLoading;
    // Refresh on the clock so time-derived status advances without an event.
    ref.watch(clockProvider);
    final now = DateTime.now();
    final inProgress = a.isInProgress(now);
    final awaitingStart = a.awaitingStart(now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$date · $time',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                _StatusPill(inProgress: inProgress, awaitingStart: awaitingStart),
              ],
            ),
            if (a.needsRescheduleConfirm) ...[
              const SizedBox(height: 10),
              _rescheduleBanner(context, ref, busy),
            ],
            const SizedBox(height: 8),
            _labeled(context, Icons.schedule, 'Trip time', '$date, $time'),
            _labeled(
                context, Icons.my_location, 'Pick-up location', a.meetingPoint),
            _labeled(
                context, Icons.place_outlined, 'Drop location', a.destination),
            _labeled(context, Icons.group_outlined, 'Users travelling',
                '${a.numTravellers}'),
            const Divider(height: 20),
            Text('User contact', style: Theme.of(context).textTheme.labelMedium),
            Semantics(
              label: 'User ${a.requesterName}, phone '
                  '${a.requesterPhone ?? 'not available'}',
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.requesterName)),
                  if (a.requesterPhone != null)
                    Text(a.requesterPhone!,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              inProgress
                  ? 'In progress — end the trip when you finish.'
                  : awaitingStart
                      ? 'Share this start code with the User to begin the trip.'
                      : 'Starts at $time. Estimated earning: '
                          '₹${a.amountInrEstimate} (${a.amountBreakdown}).',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (awaitingStart) ...[
              const SizedBox(height: 8),
              _StartCode(otp: a.startOtp),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : () => _cancel(context, ref),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                if (inProgress)
                  FilledButton.icon(
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('End trip'),
                    onPressed: busy ? null : () => _complete(context, ref),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .completeTrip(a.requestId, a.volunteerId);
    if (!context.mounted) return;
    ok ? A11y.announce(context, 'Trip ended.') : _error(context, ref);
  }

  Widget _rescheduleBanner(BuildContext context, WidgetRef ref, bool busy) {
    final scheme = Theme.of(context).colorScheme;
    final newTime =
        '${DateFormat.yMMMEd().format(a.scheduledDate)}, ${formatTime12h(a.startTime)}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Trip rescheduled',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: scheme.onTertiaryContainer)),
          ),
          const SizedBox(height: 4),
          Text(
            'The User moved this trip to $newTime. Continue with the new time, '
            'or cancel to release your slot.',
            style: TextStyle(color: scheme.onTertiaryContainer),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    busy ? null : () => _respondReschedule(context, ref, false),
                child: const Text('Cancel trip'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed:
                    busy ? null : () => _respondReschedule(context, ref, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respondReschedule(
      BuildContext context, WidgetRef ref, bool accept) async {
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .respondReschedule(a.requestId, accept);
    if (!context.mounted) return;
    ok
        ? A11y.announce(
            context,
            accept
                ? 'You confirmed the new trip time.'
                : 'You released the trip.')
        : _error(context, ref);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this trip?'),
        content: const Text(
            'This releases your slot. The User will be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep trip')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel trip')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok =
        await ref.read(requestControllerProvider.notifier).cancelTrip(a.requestId);
    if (!context.mounted) return;
    ok ? A11y.announce(context, 'Trip cancelled.') : _error(context, ref);
  }

  void _error(BuildContext context, WidgetRef ref) {
    final msg = failureMessage(ref.read(requestControllerProvider).error);
    A11y.announce(context, msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _labeled(
          BuildContext context, IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 18)),
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
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.inProgress, this.awaitingStart = false});
  final bool inProgress;
  final bool awaitingStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon, label) = inProgress
        ? (scheme.tertiaryContainer, scheme.onTertiaryContainer,
            Icons.directions_walk, 'In progress')
        : awaitingStart
            ? (scheme.tertiaryContainer, scheme.onTertiaryContainer,
                Icons.pin, 'Ready to start')
            : (scheme.secondaryContainer, scheme.onSecondaryContainer,
                Icons.schedule, 'Scheduled');
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// The TravAcser's 4-digit start code, shown large. Read digit-by-digit for
/// screen-reader users (golden rule) so it can be spoken to the User.
class _StartCode extends StatelessWidget {
  const _StartCode({required this.otp});
  final String otp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spaced = otp.split('').join(' '); // "1 2 3 4" reads digit-by-digit
    return Semantics(
      label: 'Start code: $spaced',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start code',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer)),
            const SizedBox(height: 2),
            Text(
              spaced,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
