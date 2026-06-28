import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/assignment.dart';
import '../../../domain/entities/enums.dart';
import '../../providers/request_providers.dart';
import '../requester/request_controller.dart';
import '../shared/rating_sheet.dart';

/// The TravAcser's accepted trips (their assignments), live.
class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(myAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Trips')),
      body: assignments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is Failure ? e.message : 'Could not load trips.'),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No trips yet. Accept a request from the Available tab.',
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
    final when = '${DateFormat.yMMMEd().format(a.scheduledDate)} · ${a.startTime}';
    final busy = ref.watch(requestControllerProvider).isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(when,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(a.tripStatus.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            _line(context, Icons.my_location, a.meetingPoint),
            _line(context, Icons.place_outlined,
                a.landmark == null ? a.destination : '${a.destination} (${a.landmark})'),
            const Divider(height: 20),
            Text('User contact', style: Theme.of(context).textTheme.labelMedium),
            Semantics(
              label: 'User ${a.requesterName}, phone ${a.requesterPhone ?? 'not available'}',
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
            ..._statusSection(context, ref, busy),
          ],
        ),
      ),
    );
  }

  List<Widget> _statusSection(BuildContext context, WidgetRef ref, bool busy) {
    switch (a.tripStatus) {
      case TripStatus.assigned:
        return [
          Text('Your estimated earning: ₹${a.amountInrEstimate}',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Enter OTP & start'),
              onPressed: busy ? null : () => _startDialog(context, ref),
            ),
          ),
        ];
      case TripStatus.started:
        final since = a.startedAt == null
            ? ''
            : ' since ${DateFormat.jm().format(a.startedAt!)}';
        return [
          Text('In progress$since',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Complete trip'),
              onPressed: busy ? null : () => _complete(context, ref),
            ),
          ),
        ];
      case TripStatus.completed:
      case TripStatus.closed:
        return [
          Text(
            'Completed · ${a.durationMinutes ?? 0} min · ₹${a.amountInr ?? 0} earned',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(a.paymentStatus.label)),
              if (a.travAcserReceivedAt == null)
                OutlinedButton(
                  onPressed: busy ? null : () => _markReceived(context, ref),
                  child: const Text('Mark received'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          a.ratedByVolunteer
              ? Text('You rated the User ${a.volunteerRatingStars}★')
              : Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.star_border),
                    label: const Text('Rate the User'),
                    onPressed: busy ? null : () => _rate(context, ref),
                  ),
                ),
        ];
    }
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

  Future<void> _startDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start trip'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          maxLength: AppConstants.tripOtpLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Code from the User',
            hintText: '6-digit code',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Start')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .startTrip(a.requestId, code);
    if (!context.mounted) return;
    if (ok) {
      A11y.announce(context, 'Trip started.');
    } else {
      _error(context, ref);
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .completeTrip(a.requestId, a.volunteerId);
    if (!context.mounted) return;
    if (ok) {
      A11y.announce(context, 'Trip completed.');
    } else {
      _error(context, ref);
    }
  }

  void _error(BuildContext context, WidgetRef ref) {
    final f = ref.read(requestControllerProvider).error;
    final msg = f is Failure ? f.message : 'Something went wrong.';
    A11y.announce(context, msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _line(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
