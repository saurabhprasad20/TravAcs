import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/assignment.dart';
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
      appBar: AppBar(title: const Text('My Trips')),
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
    final when = '${DateFormat.yMMMEd().format(a.scheduledDate)} · ${a.startTime}';
    final busy = ref.watch(requestControllerProvider).isLoading;
    final inProgress = a.isInProgress(DateTime.now());

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
                _StatusPill(inProgress: inProgress),
              ],
            ),
            const SizedBox(height: 6),
            _line(context, Icons.my_location, a.meetingPoint),
            _line(context, Icons.place_outlined, a.destination),
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
                  : 'Auto-starts at ${a.startTime}. Estimated earning: '
                      '₹${a.amountInrEstimate}.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
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

  Widget _line(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.inProgress});
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon, label) = inProgress
        ? (scheme.tertiaryContainer, scheme.onTertiaryContainer,
            Icons.directions_walk, 'In progress')
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
