import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/enums.dart';
import '../../../domain/entities/request.dart';

/// Shared card showing an assistance request's details. [actions] (e.g. Cancel)
/// are placed at the bottom. Used by My Requests and Available Requests.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, this.actions});

  final Request request;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final when =
        '${DateFormat.yMMMEd().format(r.scheduledDate)} · ${r.startTime}';
    final group = '${r.numTravellers} traveller(s) · '
        '${r.numTravAcsers} TravAcser(s)';

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
                _StatusChip(status: r.status),
              ],
            ),
            const SizedBox(height: 8),
            _line(context, Icons.my_location, r.meetingPoint),
            _line(context, Icons.place_outlined,
                r.landmark == null ? r.destination : '${r.destination} (${r.landmark})'),
            const SizedBox(height: 6),
            Text(group, style: Theme.of(context).textTheme.bodyMedium),
            if (r.purpose != null && r.purpose!.isNotEmpty)
              Text('Purpose: ${r.purpose}',
                  style: Theme.of(context).textTheme.bodyMedium),
            if (r.specialNote != null && r.specialNote!.isNotEmpty)
              Text('Note: ${r.specialNote}',
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('Estimated ₹${r.estimatedAmountInr}',
                style: Theme.of(context).textTheme.titleSmall),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
            ],
          ],
        ),
      ),
    );
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      RequestStatus.broadcast => (scheme.primaryContainer, scheme.onPrimaryContainer),
      RequestStatus.assigned ||
      RequestStatus.started =>
        (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      RequestStatus.completed ||
      RequestStatus.closed =>
        (scheme.secondaryContainer, scheme.onSecondaryContainer),
      RequestStatus.cancelled => (scheme.errorContainer, scheme.onErrorContainer),
      RequestStatus.draft => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
