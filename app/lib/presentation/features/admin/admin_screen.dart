import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../core/util/scheduled_time.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/pending_volunteer.dart';
import '../../../domain/entities/request.dart';
import '../../providers/admin_providers.dart';
import '../../providers/request_providers.dart';
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

/// One active trip as an accessible, labelled, TAPPABLE row. Tapping opens a
/// full-screen scrollable detail page (item 11), like the User side.
class _ActiveTripRow extends StatelessWidget {
  const _ActiveTripRow({required this.r});
  final Request r;

  @override
  Widget build(BuildContext context) {
    final when =
        '${DateFormat.yMMMEd().format(r.scheduledDate)}, ${formatTime12h(r.startTime)}';
    return Card(
      child: Semantics(
        button: true,
        label: '${r.requesterName ?? 'User'}, $when, status ${r.status.label}, '
            '${r.acceptedCount} of ${r.numTravAcsers} TravAcsers filled. '
            'Double tap to view details.',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _AdminTripDetailScreen(request: r),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
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

/// Full-screen, scrollable detail for one active trip (admin view, item 11).
/// Each field is an individual screen-reader node, plus the list of TravAcsers
/// assigned to the trip and their status.
class _AdminTripDetailScreen extends ConsumerWidget {
  const _AdminTripDetailScreen({required this.request});
  final Request request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final when =
        '${DateFormat.yMMMEd().format(r.scheduledDate)}, ${formatTime12h(r.startTime)}';
    final assignments = ref.watch(requestAssignmentsProvider(r.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Trip details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row(context, Icons.person_outline, 'User', r.requesterName ?? 'User'),
          _row(context, Icons.location_city, 'City', r.serviceCity.label),
          _row(context, Icons.schedule, 'Trip time', when),
          _row(context, Icons.flag_outlined, 'Status', r.status.label),
          _row(context, Icons.my_location, 'Pick-up location', r.meetingPoint),
          _row(context, Icons.place_outlined, 'Destination', r.destination),
          _row(context, Icons.group_outlined, 'Travellers', '${r.numTravellers}'),
          _row(context, Icons.volunteer_activism_outlined, 'TravAcsers',
              '${r.acceptedCount} of ${r.numTravAcsers} filled'),
          _row(context, Icons.wc_outlined, 'Gender preference',
              r.genderPreference.label),
          _row(context, Icons.timelapse, 'Expected duration',
              '${r.expectedDurationMinutes} min'),
          if (r.purpose != null && r.purpose!.isNotEmpty)
            _row(context, Icons.info_outline, 'Purpose', r.purpose!),
          if (r.specialNote != null && r.specialNote!.isNotEmpty)
            _row(context, Icons.sticky_note_2_outlined, 'Note', r.specialNote!),
          _row(context, Icons.currency_rupee, 'Estimated amount',
              '₹${r.estimatedAmountInr}'),
          const Divider(height: 28),
          Semantics(
            header: true,
            child: Text('Assigned TravAcsers',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 4),
          assignments.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text(failureMessage(e)),
            data: (list) {
              if (list.isEmpty) {
                return const Text('No TravAcser has accepted yet.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in list)
                    _row(context, Icons.directions_walk, a.volunteerName,
                        '${a.tripStatus.label}'
                        '${a.volunteerPhone != null ? ' · ${a.volunteerPhone}' : ''}'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(
      BuildContext context, IconData icon, String label, String value) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '$label: ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: value),
                ]),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Manual trip entry — logs a phone-booked trip into the telemetry collection.
/// Uses the same fields as the trip request form (travellers, TravAcsers, gender
/// preference, date, time, duration, meeting point, destination) plus a
/// free-text field for one or more TravAcser names (item 12).
class _ManualEntryTab extends ConsumerStatefulWidget {
  const _ManualEntryTab();

  @override
  ConsumerState<_ManualEntryTab> createState() => _ManualEntryTabState();
}

class _ManualEntryTabState extends ConsumerState<_ManualEntryTab> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _travAcserNamesController = TextEditingController();
  final _meetingController = TextEditingController();
  final _destinationController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  int _numTravellers = 1;
  int _numTravAcsers = 1;
  GenderPreference _genderPreference = GenderPreference.anyGender;
  int _durationMinutes = 60;

  static const int _minDurationMinutes = 60;
  static const int _maxDurationMinutes = 480;
  static const int _durationStepMinutes = 30;
  static const int _maxTravellers = 6;

  int get _minTravAcsers => Request.suggestedTravAcsers(_numTravellers);
  int get _estimate =>
      Request.computeEstimate(_durationMinutes, _numTravellers, _numTravAcsers);

  @override
  void dispose() {
    _userController.dispose();
    _travAcserNamesController.dispose();
    _meetingController.dispose();
    _destinationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Trip date',
    );
    if (picked != null && mounted) {
      setState(() => _date = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
        context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null && mounted) setState(() => _time = picked);
  }

  String _durationText(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hLabel = h == 1 ? '1 hour' : '$h hours';
    return m == 0 ? hLabel : '$hLabel $m min';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_date == null) {
      _announce('Please choose the trip date.');
      return;
    }
    if (_time == null) {
      _announce('Please choose the start time.');
      return;
    }
    final startTime =
        '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    final ok = await ref.read(adminControllerProvider.notifier).logManualTrip(
          userDetails: _userController.text.trim(),
          travAcserNames: _travAcserNamesController.text.trim(),
          tripDate: _date!,
          startTime: startTime,
          numTravellers: _numTravellers,
          numTravAcsers: _numTravAcsers,
          genderPreference: _genderPreference,
          durationMinutes: _durationMinutes,
          meetingPoint: _meetingController.text.trim(),
          destination: _destinationController.text.trim(),
          estimatedAmountInr: _estimate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      _announce('Manual trip logged.');
      _formKey.currentState?.reset();
      _userController.clear();
      _travAcserNamesController.clear();
      _meetingController.clear();
      _destinationController.clear();
      _noteController.clear();
      setState(() {
        _date = null;
        _time = null;
        _numTravellers = 1;
        _numTravAcsers = 1;
        _genderPreference = GenderPreference.anyGender;
        _durationMinutes = 60;
      });
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
    final maxTravAcsers = _numTravellers;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log a trip booked outside the app (e.g. by phone) in the same '
                'format as a request, so it is captured in the trip records.',
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
              // The extra field (item 12): one or more TravAcser names.
              TextFormField(
                controller: _travAcserNamesController,
                decoration: const InputDecoration(
                  labelText: 'TravAcser names (one or more)',
                  hintText: 'e.g. Ravi Kumar, Priya Singh',
                ),
                validator: _required,
              ),
              const Divider(height: 24),
              DropdownButtonFormField<int>(
                value: _numTravellers,
                decoration:
                    const InputDecoration(labelText: 'Number of travellers'),
                items: [
                  for (var i = 1; i <= _maxTravellers; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (v) => setState(() {
                  _numTravellers = v ?? 1;
                  // Reset to the suggested count so the TravAcser value always
                  // stays within the (min..travellers) dropdown range.
                  _numTravAcsers = Request.suggestedTravAcsers(_numTravellers);
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _numTravAcsers,
                decoration:
                    const InputDecoration(labelText: 'Number of TravAcsers'),
                items: [
                  for (var i = _minTravAcsers; i <= maxTravAcsers; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (v) =>
                    setState(() => _numTravAcsers = v ?? _minTravAcsers),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GenderPreference>(
                value: _genderPreference,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'TravAcser gender preference'),
                items: GenderPreference.values
                    .map((g) =>
                        DropdownMenuItem(value: g, child: Text(g.label)))
                    .toList(),
                onChanged: (g) => setState(
                    () => _genderPreference = g ?? GenderPreference.anyGender),
              ),
              const Divider(height: 24),
              Semantics(
                button: true,
                excludeSemantics: true,
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
              Semantics(
                button: true,
                excludeSemantics: true,
                label: 'Start time, ${_time?.format(context) ?? 'not set'}',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start time'),
                  subtitle: Text(_time?.format(context) ?? 'Not set'),
                  trailing: const Icon(Icons.access_time),
                  onTap: _pickTime,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expected duration: ${_durationText(_durationMinutes)}',
                      style: Theme.of(context).textTheme.labelLarge),
                  Slider(
                    value: _durationMinutes.toDouble(),
                    min: _minDurationMinutes.toDouble(),
                    max: _maxDurationMinutes.toDouble(),
                    divisions: (_maxDurationMinutes - _minDurationMinutes) ~/
                        _durationStepMinutes,
                    label: _durationText(_durationMinutes),
                    semanticFormatterCallback: (v) => _durationText(v.round()),
                    onChanged: (v) =>
                        setState(() => _durationMinutes = v.round()),
                  ),
                ],
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _meetingController,
                decoration:
                    const InputDecoration(labelText: 'Meeting point'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destinationController,
                decoration: const InputDecoration(labelText: 'Destination'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 12),
              Text('Estimated amount: ₹$_estimate',
                  style: Theme.of(context).textTheme.titleMedium),
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
    controller.dispose();
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
