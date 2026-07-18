import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/entities/request.dart';
import '../../providers/profile_providers.dart';
import '../../providers/request_providers.dart';
import '../../providers/shell_providers.dart';
import 'request_controller.dart';

/// New assistance request form. The city is taken from the requester's profile;
/// an estimate review is shown before submit. Only the initiating User's
/// details are kept — extra travellers are just a count (M12).
class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meetingController = TextEditingController();
  final _destinationController = TextEditingController();
  final _purposeController = TextEditingController();
  final _noteController = TextEditingController();

  int _numTravellers = 1;
  int _numTravAcsers = 1;
  GenderPreference _genderPreference = GenderPreference.anyGender;
  DateTime? _date;
  TimeOfDay? _time;
  int _durationMinutes = 60;

  // Duration options (label → minutes).
  static const _durations = <String, int>{
    '1 hour': 60,
    '1.5 hours': 90,
    '2 hours': 120,
    '3 hours': 180,
    '4 hours': 240,
    '6 hours': 360,
    '8 hours': 480,
  };

  @override
  void dispose() {
    _meetingController.dispose();
    _destinationController.dispose();
    _purposeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _minTravAcsers => Request.suggestedTravAcsers(_numTravellers);
  int get _estimate =>
      Request.computeEstimate(_durationMinutes, _numTravellers, _numTravAcsers);

  /// Caps for the party size (design: up to 6 travellers, up to 6 TravAcsers).
  static const int _maxTravellers = 6;

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'Select trip date',
    );
    if (picked != null) setState(() => _date = DateUtils.dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  String? _validateSchedule() {
    if (_date == null) return 'Please choose a trip date.';
    if (_time == null) return 'Please choose a start time.';
    return null;
  }

  Future<void> _review(MyProfile my) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final scheduleError = _validateSchedule();
    if (scheduleError != null) {
      _announceError(scheduleError);
      return;
    }

    // Block creating a new trip while the User has unpaid completed trips. Read
    // the underlying stream's state so we don't fall through while it's still
    // loading (its `.value` would be null and the dues would look empty).
    final duesAsync = ref.read(myRequesterAssignmentsProvider);
    if (duesAsync.isLoading) {
      if (!mounted) return;
      _announceError('Checking your account… please tap submit again in a moment.');
      return;
    }
    if (ref.read(myPendingDuesProvider).isNotEmpty) {
      if (!mounted) return;
      const msg =
          'Alert, you have pending dues, kindly clear them before creating new ones.';
      A11y.announce(context, msg);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pending dues'),
          content: const Text(msg),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Dismiss the keyboard so the review sheet gets full height (otherwise the
    // preview overflows behind the keyboard and only the button shows).
    FocusScope.of(context).unfocus();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(
        date: _date!,
        time: _time!.format(context),
        durationLabel: _durationLabel(),
        numTravellers: _numTravellers,
        numTravAcsers: _numTravAcsers,
        genderPreference: _genderPreference,
        meetingPoint: _meetingController.text.trim(),
        destination: _destinationController.text.trim(),
        purpose: _purposeController.text.trim(),
        specialNote: _noteController.text.trim(),
        estimate: _estimate,
      ),
    );
    if (confirmed != true || !mounted) return;
    await _submit(my);
  }

  Future<void> _submit(MyProfile my) async {
    final time = _time!;
    final startTime =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    final id = await ref.read(requestControllerProvider.notifier).create(
          serviceState: my.profile.serviceArea!,
          serviceCity: my.profile.serviceCity!,
          requesterName: my.profile.fullName,
          numTravellers: _numTravellers,
          numTravAcsers: _numTravAcsers,
          genderPreference: _genderPreference,
          scheduledDate: _date!,
          startTime: startTime,
          expectedDurationMinutes: _durationMinutes,
          meetingPoint: _meetingController.text.trim(),
          destination: _destinationController.text.trim(),
          requesterGender: my.profile.gender,
          purpose: _emptyToNull(_purposeController.text),
          specialNote: _emptyToNull(_noteController.text),
        );
    if (!mounted) return;
    if (id != null) {
      // Drop any lingering text-field focus so the soft keyboard closes as we
      // move to My Requests (focus can be restored after the review sheet pops).
      FocusManager.instance.primaryFocus?.unfocus();
      A11y.announce(context, 'Request submitted. TravAcsers in your city are '
          'being notified.');
      _resetForm();
      // Take the user to My Requests so they see the request they just created.
      ref.read(shellTabIndexProvider.notifier).set(requesterMyRequestsTabIndex);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Request submitted.')));
    } else {
      _announceError(
          failureMessage(ref.read(requestControllerProvider).error));
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _meetingController.clear();
    _destinationController.clear();
    _purposeController.clear();
    _noteController.clear();
    setState(() {
      _numTravellers = 1;
      _numTravAcsers = 1;
      _genderPreference = GenderPreference.anyGender;
      _date = null;
      _time = null;
      _durationMinutes = 60;
    });
  }

  void _announceError(String msg) {
    A11y.announce(context, msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _emptyToNull(String s) => s.trim();
  String _durationLabel() => _durations.entries
      .firstWhere((e) => e.value == _durationMinutes,
          orElse: () => const MapEntry('', 60))
      .key;

  @override
  Widget build(BuildContext context) {
    final my = ref.watch(myProfileProvider).value;
    final busy = ref.watch(requestControllerProvider).isLoading;
    // Warm the requester's assignments stream so the pending-dues check has data
    // ready by the time the user taps submit (otherwise its first read returns
    // an empty/loading value and the dues block is silently bypassed).
    ref.watch(myRequesterAssignmentsProvider);

    return Scaffold(
      body: my == null
          ? const Center(child: CircularProgressIndicator())
          : !my.profile.hasServiceArea
              ? _NeedsServiceArea()
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section(
                              'Your city / location: ${my.profile.serviceCity!.label}'),
                          _travellerDropdown(),
                          Text(
                            'Only your contact details are shared with the '
                            'TravAcser. You are responsible for the trip and '
                            'payment; others are counted for planning.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          _travAcserDropdown(),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<GenderPreference>(
                            value: _genderPreference,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'TravAcser gender preference'),
                            items: GenderPreference.values
                                .map((g) => DropdownMenuItem(
                                    value: g, child: Text(g.label)))
                                .toList(),
                            onChanged: (g) => setState(() => _genderPreference =
                                g ?? GenderPreference.anyGender),
                          ),
                          if (_genderPreference ==
                              GenderPreference.strictSameGender) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Shown to same-gender TravAcsers first. If it stays '
                              'unfilled, it opens to all genders as the trip time '
                              'nears (we\'ll let you know).',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const Divider(height: 24),
                          _datePicker(),
                          const SizedBox(height: 12),
                          _timePicker(),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _durationMinutes,
                            decoration: const InputDecoration(
                                labelText: 'Expected duration'),
                            items: _durations.entries
                                .map((e) => DropdownMenuItem(
                                    value: e.value, child: Text(e.key)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _durationMinutes = v ?? 60),
                          ),
                          const Divider(height: 24),
                          TextFormField(
                            controller: _meetingController,
                            decoration: const InputDecoration(
                                labelText: 'Meeting point with the TravAcser'),
                            validator: _required,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _destinationController,
                            decoration: const InputDecoration(
                                labelText: 'Destination / event location'),
                            validator: _required,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _purposeController,
                            decoration: const InputDecoration(
                                labelText: 'Purpose of the trip',
                                hintText: 'e.g. Medical appointment'),
                            validator: _required,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _noteController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Special note / requirement (optional)',
                              helperText:
                                  'e.g. specific gender-preference details, '
                                  'mobility aids, timing or language notes',
                              helperMaxLines: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: ListTile(
                              title: const Text('Estimated bill'),
                              subtitle: const Text(
                                  'Estimate only; final amount depends on the '
                                  'actual trip duration.'),
                              trailing: Text('₹$_estimate',
                                  style: Theme.of(context).textTheme.titleLarge),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: busy ? null : () => _review(my),
                            child: busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5))
                                : const Text('Review & submit'),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  /// Traveller count as an accessible 1–[_maxTravellers] dropdown (mirrors the
  /// TravAcser dropdown). Replaces the old +/- stepper. Changing it auto-sets
  /// the suggested TravAcser count (one TravAcser assists up to 2 travellers).
  Widget _travellerDropdown() {
    return DropdownButtonFormField<int>(
      value: _numTravellers,
      decoration: const InputDecoration(
        labelText: 'Total travellers (including you)',
      ),
      items: [
        for (var i = 1; i <= _maxTravellers; i++)
          DropdownMenuItem(value: i, child: Text('$i')),
      ],
      onChanged: (v) => setState(() {
        _numTravellers = v ?? 1;
        // Auto-set to the suggested count; the user may then raise it up to the
        // number of travellers (the TravAcser dropdown range).
        _numTravAcsers = Request.suggestedTravAcsers(_numTravellers);
      }),
    );
  }

  /// TravAcser count as an accessible dropdown ranging from the suggested count
  /// (ceil(travellers / 2)) up to the number of travellers — one TravAcser
  /// assists up to 2 travellers. A slider was hard to use with a screen reader.
  Widget _travAcserDropdown() {
    final min = _minTravAcsers;
    final max = _numTravellers;
    return DropdownButtonFormField<int>(
      value: _numTravAcsers,
      decoration: InputDecoration(
        labelText: 'TravAcsers required',
        helperText: 'Suggested $min for $_numTravellers '
            'traveller${_numTravellers == 1 ? '' : 's'} — one TravAcser assists '
            'up to 2 travellers (up to $max)',
        helperMaxLines: 2,
      ),
      items: [
        for (var i = min; i <= max; i++)
          DropdownMenuItem(value: i, child: Text('$i')),
      ],
      onChanged: (v) => setState(() => _numTravAcsers = v ?? min),
    );
  }

  Widget _datePicker() {
    final now = DateUtils.dateOnly(DateTime.now());
    final quick = <String, DateTime>{
      'Today': now,
      'Tomorrow': now.add(const Duration(days: 1)),
      'Day after': now.add(const Duration(days: 2)),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trip date', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final e in quick.entries)
              ChoiceChip(
                label: Text(e.key),
                selected: _date == e.value,
                onSelected: (_) => setState(() => _date = e.value),
              ),
            ActionChip(
              avatar: const Icon(Icons.calendar_today, size: 18),
              label: Text(_date != null && !quick.containsValue(_date)
                  ? DateFormat.yMMMd().format(_date!)
                  : 'Custom'),
              onPressed: _pickCustomDate,
            ),
          ],
        ),
        if (_date != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Selected: ${DateFormat.yMMMEd().format(_date!)}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _timePicker() {
    return Semantics(
      button: true,
      label: 'Start time, ${_time?.format(context) ?? 'not set'}',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Start time (when your trip is scheduled to begin)'),
        subtitle: Text(_time?.format(context) ?? 'Not set'),
        trailing: const Icon(Icons.access_time),
        onTap: _pickTime,
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

/// Shown when the requester has no service area yet (legacy profile).
class _NeedsServiceArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Please set your city / location on the Profile tab before creating '
          'a request.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Final review sheet showing the estimate before submitting.
class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({
    required this.date,
    required this.time,
    required this.durationLabel,
    required this.numTravellers,
    required this.numTravAcsers,
    required this.genderPreference,
    required this.meetingPoint,
    required this.destination,
    required this.purpose,
    required this.specialNote,
    required this.estimate,
  });

  final DateTime date;
  final String time;
  final String durationLabel;
  final int numTravellers;
  final int numTravAcsers;
  final GenderPreference genderPreference;
  final String meetingPoint;
  final String destination;
  final String purpose;
  final String specialNote;
  final int estimate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('Review your request',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 12),
              _row('When', '${DateFormat.yMMMEd().format(date)} at $time'),
              _row('Duration', durationLabel),
              _row('Travellers', '$numTravellers'),
              _row('TravAcsers', '$numTravAcsers'),
              _row('Gender preference', genderPreference.label),
              _row('Meeting point', meetingPoint),
              _row('Destination', destination),
              if (purpose.isNotEmpty) _row('Purpose', purpose),
              if (specialNote.isNotEmpty) _row('Special note', specialNote),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estimated bill',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('₹$estimate',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'This is an estimate based on the expected duration '
                '(₹${AppConstants.rateSoloInr}/hour per TravAcser for one '
                'traveller, ₹${AppConstants.ratePairInr}/hour for two, plus '
                '₹${AppConstants.travelCostInr} travel per TravAcser). The final '
                'amount may vary with the actual trip duration.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit request'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(k)),
            Expanded(
                child: Text(v,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
