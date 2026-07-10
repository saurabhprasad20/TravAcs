import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../core/util/scheduled_time.dart';
import '../../../domain/entities/pending_volunteer.dart';
import '../../../domain/entities/request.dart';
import '../../providers/admin_providers.dart';
import '../menu/app_menu_drawer.dart';
import 'admin_controller.dart';

/// In-app admin panel. Tab 1 approves/rejects pending TravAcsers; Tab 2 is a
/// live monitoring dashboard of all active trips (admin claim only).
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Verifications'),
              Tab(text: 'Active trips'),
              Tab(text: 'Manual entry'),
            ],
          ),
        ),
        drawer: const AppMenuDrawer(),
        body: const TabBarView(
          children: [
            _VerificationsTab(),
            _ActiveTripsTab(),
            _ManualEntryTab(),
          ],
        ),
      ),
    );
  }
}

/// Pending-TravAcser verification queue (the original admin view).
class _VerificationsTab extends ConsumerWidget {
  const _VerificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingVolunteersProvider);

    return pending.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(failureMessage(e))),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No TravAcsers awaiting verification.',
                  textAlign: TextAlign.center),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, i) => _PendingCard(v: list[i]),
        );
      },
    );
  }
}

/// Live tabular dashboard of every active (open / assigned / in-progress) trip.
class _ActiveTripsTab extends ConsumerWidget {
  const _ActiveTripsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(activeTripsProvider);

    return trips.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(failureMessage(e))),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No active trips right now.',
                  textAlign: TextAlign.center),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Semantics(
                header: true,
                child: Text('${list.length} active trip'
                    '${list.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (context, i) => _ActiveTripRow(r: list[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One active trip as an accessible, labelled card (a screen-reader-friendly
/// "row" — each field is announced with its column name).
class _ActiveTripRow extends StatelessWidget {
  const _ActiveTripRow({required this.r});
  final Request r;

  @override
  Widget build(BuildContext context) {
    final when =
        '${DateFormat.yMMMEd().format(r.scheduledDate)}, ${formatTime12h(r.startTime)}';
    return Card(
      child: MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.requesterName ?? 'User',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              _cell(context, 'City', r.serviceCity.label),
              _cell(context, 'When', when),
              _cell(context, 'Status', r.status.label),
              _cell(context, 'TravAcsers',
                  '${r.acceptedCount} of ${r.numTravAcsers} filled'),
              _cell(context, 'Travellers', '${r.numTravellers}'),
              _cell(context, 'Route', '${r.meetingPoint} \u2192 ${r.destination}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ]),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
}

/// Manual trip entry — logs a phone-booked trip into the telemetry collection
/// (item 4). Two free-text fields (User + TravAcser details) plus the trip date
/// and an optional note.
class _ManualEntryTab extends ConsumerStatefulWidget {
  const _ManualEntryTab();

  @override
  ConsumerState<_ManualEntryTab> createState() => _ManualEntryTabState();
}

class _ManualEntryTabState extends ConsumerState<_ManualEntryTab> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _travAcserController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _userController.dispose();
    _travAcserController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Trip date',
    );
    if (picked != null) setState(() => _date = DateUtils.dateOnly(picked));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_date == null) {
      _announce('Please choose the trip date.');
      return;
    }
    final ok = await ref.read(adminControllerProvider.notifier).logManualTrip(
          userDetails: _userController.text.trim(),
          travAcserDetails: _travAcserController.text.trim(),
          tripDate: _date!,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      _announce('Manual trip logged.');
      _formKey.currentState?.reset();
      _userController.clear();
      _travAcserController.clear();
      _noteController.clear();
      setState(() => _date = null);
    } else {
      _announce(failureMessage(ref.read(adminControllerProvider).error));
    }
  }

  void _announce(String msg) {
    A11y.announce(context, msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(adminControllerProvider).isLoading;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log a trip booked outside the app (e.g. by phone) so it is '
                'captured in the trip records.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: 'User details',
                  hintText: 'Name and phone of the User',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _travAcserController,
                decoration: const InputDecoration(
                  labelText: 'TravAcser details',
                  hintText: 'Name and phone of the TravAcser',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label:
                    'Trip date, ${_date == null ? 'not set' : DateFormat.yMMMEd().format(_date!)}',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Trip date'),
                  subtitle: Text(_date == null
                      ? 'Not set'
                      : DateFormat.yMMMEd().format(_date!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Log trip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingCard extends ConsumerWidget {
  const _PendingCard({required this.v});
  final PendingVolunteer v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(adminControllerProvider).isLoading;
    final region = [v.city?.label, v.state?.label]
        .where((s) => s != null)
        .join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v.fullName, style: Theme.of(context).textTheme.titleMedium),
            if (v.phone != null) _row(Icons.phone_outlined, v.phone!),
            if (region.isNotEmpty) _row(Icons.place_outlined, region),
            if (v.address != null) _row(Icons.home_outlined, v.address!),
            if (v.gender != null) _row(Icons.person_outline, v.gender!.label),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => _reject(context, ref),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : () => _approve(context, ref),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(adminControllerProvider.notifier).approve(v.uid);
    if (context.mounted) {
      ok
          ? A11y.announce(context, '${v.fullName} approved.')
          : _err(context, ref);
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${v.fullName}?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Reject')),
        ],
      ),
    );
    if (reason == null) return; // cancelled
    final ok = await ref
        .read(adminControllerProvider.notifier)
        .reject(v.uid, reason.isEmpty ? null : reason);
    if (context.mounted) {
      ok
          ? A11y.announce(context, '${v.fullName} rejected.')
          : _err(context, ref);
    }
  }

  void _err(BuildContext context, WidgetRef ref) {
    final msg = failureMessage(ref.read(adminControllerProvider).error);
    A11y.announce(context, msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
