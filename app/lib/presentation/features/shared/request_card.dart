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
        '${r.acceptedCount}/${r.numTravAcsers} TravAcser(s) filled';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Merge the informational block into a single semantic node so a
            // screen-reader swipe lands on the card as one coherent summary
            // instead of fragment by fragment. The [actions] below stay outside
            // the merge so each keeps its own (button) tap semantics.
            MergeSemantics(
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
                  _line(context, Icons.place_outlined, r.destination),
                  const SizedBox(height: 6),
                  Text(group, style: Theme.of(context).textTheme.bodyMedium),
                  Text('TravAcser preference: ${r.genderPreference.label}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (r.purpose != null && r.purpose!.isNotEmpty)
                    Text('Purpose: ${r.purpose}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  if (r.specialNote != null && r.specialNote!.isNotEmpty)
                    Text('Note: ${r.specialNote}',
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text('Estimated ₹${r.estimatedAmountInr}',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
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
            // Decorative — the adjacent text carries the meaning.
            ExcludeSemantics(child: Icon(icon, size: 18)),
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
    // Each status carries both a colour AND an icon so it is never conveyed by
    // colour alone (M9, §11). The icon is exposed to screen readers via the
    // chip's [Semantics] label, not the glyph itself.
    final (bg, fg, icon) = switch (status) {
      RequestStatus.broadcast => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.campaign_outlined,
        ),
      RequestStatus.assigned || RequestStatus.started => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.directions_walk,
        ),
      RequestStatus.completed || RequestStatus.closed => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.check_circle_outline,
        ),
      RequestStatus.cancelled => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.cancel_outlined,
        ),
      RequestStatus.draft => (
          scheme.surfaceContainerHighest,
          scheme.onSurface,
          Icons.edit_outlined,
        ),
    };
    return Semantics(
      label: 'Status: ${status.label}',
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
            Text(status.label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
