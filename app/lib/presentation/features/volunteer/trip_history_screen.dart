import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/assignment.dart';
import '../../../domain/entities/enums.dart';
import '../../providers/request_providers.dart';
import '../../providers/core_providers.dart';
import '../menu/info_screens.dart';
import '../requester/request_controller.dart';
import '../shared/history_controls.dart';
import '../shared/rating_sheet.dart';

/// The TravAcser's completed/closed/cancelled trips (Trip History tab). Shows
/// each trip's date/destination/duration, payment status (informational — the
/// User pays the app once per trip and the admin distributes shares), and a
/// per-trip "Rate the User". No earnings figures are shown. Ordered newest
/// first, filterable, and capped at the most recent [kHistoryPageSize].
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
          final terminal = all.where((a) => a.tripStatus.isTerminal).toList();

          var list =
              terminal.where((a) => _matchesFilter(a.tripStatus)).toList();
          DateTime key(Assignment a) => a.acceptedAt ?? a.scheduledDate;
          list.sort(
            (x, y) =>
                _sort == HistorySort.newest
                    ? key(y).compareTo(key(x))
                    : key(x).compareTo(key(y)),
          );
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
                child:
                    shown.isEmpty
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No trips yet.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: shown.length,
                          itemBuilder:
                              (context, i) => _HistoryCard(a: shown[i]),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesFilter(TripStatus s) => switch (_filter) {
    HistoryFilter.all => true,
    HistoryFilter.completed =>
      s == TripStatus.completed || s == TripStatus.closed,
    HistoryFilter.cancelled => s == TripStatus.cancelled,
  };
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.a});
  final Assignment a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when = DateFormat.yMMMEd().format(a.scheduledDate);
    final busy = ref.watch(requestControllerProvider).isLoading;
    final cancelled = a.tripStatus == TripStatus.cancelled;
    ref.watch(clockProvider);
    final canSubmitExpense = a.canSubmitExpense(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$when · ${a.destination}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  if (cancelled)
                    const Text('Cancelled')
                  else ...[
                    Text(
                      '${a.durationMinutes ?? 0} min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    // Payment status is informational: the User pays the app once
                    // for the whole trip; each TravAcser's share is transferred by
                    // the admin team afterwards (no in-app "mark received" step).
                    Text(
                      'Payment: ${a.paymentStatus.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.help_outline, semanticLabel: 'Get help'),
                label: const Text('Get help'),
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ContactUsScreen(),
                      ),
                    ),
              ),
            ),
            if (!cancelled) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (canSubmitExpense)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Submit travel cost'),
                      onPressed:
                          busy ? null : () => _submitExpense(context, ref),
                    )
                  else if (a.expenseClaimStatus == 'submitted' ||
                      a.expenseClaimStatus == 'reviewed')
                    Text(
                      'Travel cost submitted'
                      '${a.additionalTravelCostClaimedInr != null ? ': ₹${a.additionalTravelCostClaimedInr} additional' : ''}',
                    ),
                  if (a.ratedByVolunteer)
                    Text('You rated ${a.volunteerRatingStars}★')
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.star_border),
                      label: const Text('Rate the User'),
                      onPressed: busy ? null : () => _rate(context, ref),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitExpense(BuildContext context, WidgetRef ref) async {
    final amountController = TextEditingController(text: '0');
    XFile? receipt;
    String? amountError;
    final result = await showDialog<(int, XFile?)>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Travel cost request'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enter only the additional travel cost beyond the default '
                        'amount. Both the added cost and receipt are optional.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Additional travel cost in rupees',
                          prefixText: '₹',
                        ).copyWith(errorText: amountError),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          receipt == null
                              ? 'Choose receipt image'
                              : receipt!.name,
                        ),
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                            maxWidth: 2048,
                          );
                          if (picked != null) {
                            setDialogState(() => receipt = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final amount = int.tryParse(
                          amountController.text.trim(),
                        );
                        if (amount == null || amount < 0 || amount > 10000) {
                          setDialogState(() {
                            amountError = 'Enter an amount from ₹0 to ₹10,000.';
                          });
                          return;
                        }
                        Navigator.pop(dialogContext, (amount, receipt));
                      },
                      child: const Text('Submit request'),
                    ),
                  ],
                ),
          ),
    );
    amountController.dispose();
    if (result == null || !context.mounted) return;

    String? receiptPath;
    final selectedReceipt = result.$2;
    if (selectedReceipt != null) {
      final bytes = await selectedReceipt.readAsBytes();
      final mime =
          selectedReceipt.mimeType == 'image/png' ? 'image/png' : 'image/jpeg';
      receiptPath = await ref
          .read(requestControllerProvider.notifier)
          .uploadTravelReceipt(
            requestId: a.requestId,
            bytes: bytes,
            contentType: mime,
          );
      if (!context.mounted) return;
      if (receiptPath == null) {
        _error(context, ref);
        return;
      }
    }
    final ok = await ref
        .read(requestControllerProvider.notifier)
        .submitTravelExpense(
          requestId: a.requestId,
          additionalTravelCostInr: result.$1,
          receiptPath: receiptPath,
        );
    if (!context.mounted) return;
    ok
        ? A11y.announce(context, 'Travel cost request submitted.')
        : _error(context, ref);
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

  void _error(BuildContext context, WidgetRef ref) {
    final msg = failureMessage(ref.read(requestControllerProvider).error);
    A11y.announce(context, msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}
