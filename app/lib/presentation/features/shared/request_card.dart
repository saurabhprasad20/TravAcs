import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/util/scheduled_time.dart';
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
    final date = DateFormat.yMMMEd().format(r.scheduledDate);
    final time = formatTime12h(r.startTime);

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
                        child: Text('$date · $time',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      RequestStatusChip(status: r.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _labeled(context, Icons.schedule, 'Trip time',
                      '$date, $time'),
                  _labeled(context, Icons.my_location, 'Pick-up location',
                      r.meetingPoint),
                  _labeled(context, Icons.place_outlined, 'Destination',
                      r.destination),
                  _labeled(context, Icons.group_outlined, 'Users travelling',
                      '${r.numTravellers}'),
                  _labeled(context, Icons.volunteer_activism_outlined,
                      'TravAcsers required',
                      '${r.acceptedCount}/${r.numTravAcsers} filled'),
                  _labeled(context, Icons.wc_outlined, 'TravAcser preference',
                      r.genderPreference.label),
                  if (r.purpose != null && r.purpose!.isNotEmpty)
                    _labeled(context, Icons.info_outline, 'Purpose', r.purpose!),
                  if (r.specialNote != null && r.specialNote!.isNotEmpty)
                    _labeled(context, Icons.sticky_note_2_outlined, 'Note',
                        r.specialNote!),
                  const SizedBox(height: 8),
                  _labeled(context, Icons.currency_rupee, 'Estimated amount',
                      '₹${r.estimatedAmountInr}  (${r.estimateBreakdown})'),
                ],
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              // Wrap (not Row) so action buttons flow onto the next line instead
              // of overflowing/clipping off the right edge at large text scales.
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A labelled detail line: a decorative icon plus "Label: value" text. The
  /// explicit label keeps the dense card readable (and reads naturally on a
  /// screen reader) instead of a cluttered pile of bare values.
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

/// Status pill for a request — colour AND icon AND text (never colour alone).
/// Exposed for reuse by the My Requests summary tile + detail page.
class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip({super.key, required this.status});
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
