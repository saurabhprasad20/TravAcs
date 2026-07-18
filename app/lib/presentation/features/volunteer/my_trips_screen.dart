import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import '../../../core/util/scheduled_time.dart';
import '../../../domain/entities/assignment.dart';
import '../../providers/core_providers.dart';
import '../../providers/request_providers.dart';
import '../menu/info_screens.dart';
import '../requester/request_controller.dart';

/// The TravAcser's ACTIVE trips (scheduled or in progress), live. Completed
/// trips move to the Trip History tab. A trip starts when the TravAcser
/// validates the User's start code; either party can end a started trip.
class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    // The trip can be started any time after acceptance (parties often meet
    // early) — as long as it isn't already in progress and there's no pending
    // reschedule to confirm first. Billing runs from the actual start.
    final canStart = !inProgress && !a.needsRescheduleConfirm;
    // A trip may start early, but it can only be ENDED at/after its scheduled
    // start time (matches the server's EARLY_END guard).
    final canEnd = inProgress && !now.isBefore(a.effectiveStartAt);

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
                _StatusPill(inProgress: inProgress, readyToStart: canStart),
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
                context, Icons.place_outlined, 'Destination', a.destination),
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
                  ? (canEnd
                      ? 'In progress — end the trip when you finish.'
                      : 'In progress — you can end the trip once its scheduled '
                          'start time ($time) arrives.')
                  : canStart
                      ? 'Ask the User for their start code and enter it to begin '
                          'the trip. Scheduled for $time — you can start early if '
                          'you meet sooner.'
                      : 'Starts at $time.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (canStart) ...[
              const SizedBox(height: 8),
              _StartCodeEntry(
                requestId: a.requestId,
                volunteerId: a.volunteerId,
                expectedOtp: a.startOtp,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.help_outline, semanticLabel: 'Get help'),
                  label: const Text('Get help'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ContactUsScreen()),
                  ),
                ),
                // Once a trip has started it can only be ended, never cancelled.
                if (!inProgress)
                  TextButton(
                    onPressed: busy ? null : () => _cancel(context, ref),
                    child: const Text('Cancel'),
                  ),
                if (inProgress)
                  FilledButton.icon(
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('End trip'),
                    onPressed:
                        (busy || !canEnd) ? null : () => _complete(context, ref),
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
  const _StatusPill({required this.inProgress, this.readyToStart = false});
  final bool inProgress;
  final bool readyToStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon, label) = inProgress
        ? (scheme.tertiaryContainer, scheme.onTertiaryContainer,
            Icons.directions_walk, 'In progress')
        : readyToStart
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

/// The TravAcser starts the trip by entering the User's 4-digit start code.
/// Tapping "Start trip" opens a dialog with a numeric input; validation is fully
/// offline (compared against [Assignment.startOtp]). Only on a match do we call
/// the server to record the "In progress" flip, after which both parties see the
/// trip as started.
class _StartCodeEntry extends ConsumerStatefulWidget {
  const _StartCodeEntry({
    required this.requestId,
    required this.volunteerId,
    required this.expectedOtp,
  });
  final String requestId;
  final String volunteerId;
  final String expectedOtp;

  @override
  ConsumerState<_StartCodeEntry> createState() => _StartCodeEntryState();
}

class _StartCodeEntryState extends ConsumerState<_StartCodeEntry> {
  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(requestControllerProvider).isLoading;
    return FilledButton.icon(
      icon: const Icon(Icons.play_arrow),
      label: const Text('Start trip'),
      onPressed: busy ? null : _openCodeDialog,
    );
  }

  Future<void> _openCodeDialog() async {
    // The dialog validates the entered code offline and only pops `true` on a
    // correct 4-digit code (otherwise it shows an inline error and stays open).
    final matched = await showDialog<bool>(
      context: context,
      builder: (_) => _StartCodeDialog(expectedOtp: widget.expectedOtp),
    );
    if (matched != true || !mounted) return;

    // Capture the messenger + text direction BEFORE the await: a successful
    // start flips the assignment stream to "started", which rebuilds the card
    // and unmounts this entry — so a post-await `mounted` check would swallow
    // the success announcement. The messenger lives above the card and survives.
    final messenger = ScaffoldMessenger.of(context);
    final dir = Directionality.of(context);
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .startTrip(widget.requestId, widget.volunteerId);
    if (ok) {
      _announce(messenger, dir, 'Code validated. The trip has started.');
    } else {
      _announce(
          messenger, dir, failureMessage(ref.read(requestControllerProvider).error));
    }
  }

  void _announce(
      ScaffoldMessengerState messenger, TextDirection dir, String msg) {
    SemanticsService.announce(msg, dir);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Dialog that collects the User's start code. Pops `true` only when the entered
/// code matches [expectedOtp]; a wrong code shows an inline error and keeps the
/// dialog open so the TravAcser can re-check with the User and retry.
class _StartCodeDialog extends StatefulWidget {
  const _StartCodeDialog({required this.expectedOtp});
  final String expectedOtp;

  @override
  State<_StartCodeDialog> createState() => _StartCodeDialogState();
}

class _StartCodeDialogState extends State<_StartCodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final entered = _controller.text.trim();
    if (entered.length != AppConstants.tripOtpLength) {
      setState(() => _error =
          'Enter the ${AppConstants.tripOtpLength}-digit code from the User.');
      A11y.announce(context, _error!);
      return;
    }
    if (entered != widget.expectedOtp) {
      setState(() => _error =
          "That code doesn't match. Please check with the User and try again.");
      A11y.announce(context, _error!);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter start code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask the User for their ${AppConstants.tripOtpLength}-digit start '
            'code and enter it here to begin the trip.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: AppConstants.tripOtpLength,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Start code',
              hintText: '4-digit code',
              counterText: '',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start trip'),
          onPressed: _submit,
        ),
      ],
    );
  }
}
