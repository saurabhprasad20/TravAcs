import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/entities/request.dart';
import '../../providers/profile_providers.dart';
import 'request_controller.dart';

/// New assistance request form (fields per userRequestForm.txt). Region is taken
/// from the requester's profile; an estimate review is shown before submit.
class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meetingController = TextEditingController();
  final _destinationController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _purposeController = TextEditingController();
  final _noteController = TextEditingController();

  int _numTravellers = 1;
  int _numTravAcsers = 1;
  int _numMale = 0;
  int _numFemale = 1;
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
    _landmarkController.dispose();
    _purposeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _minTravAcsers => Request.suggestedTravAcsers(_numTravellers);
  int get _estimate => Request.computeEstimate(_durationMinutes, _numTravAcsers);

  void _setTravellers(int v) {
    setState(() {
      _numTravellers = v.clamp(1, 20);
      // Keep TravAcsers within [min, travellers].
      _numTravAcsers = _numTravAcsers.clamp(_minTravAcsers, _numTravellers);
      // Reset gender split if it now exceeds travellers.
      if (_numMale + _numFemale != _numTravellers) {
        _numMale = 0;
        _numFemale = _numTravellers;
      }
    });
  }

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

  String? _validateGroup() {
    if (_numTravAcsers < _minTravAcsers || _numTravAcsers > _numTravellers) {
      return 'TravAcsers must be between $_minTravAcsers and $_numTravellers.';
    }
    if (_numMale + _numFemale != _numTravellers) {
      return 'Male + female travellers must equal $_numTravellers.';
    }
    if (_date == null) return 'Please choose a trip date.';
    if (_time == null) return 'Please choose a start time.';
    return null;
  }

  Future<void> _review(MyProfile my) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final groupError = _validateGroup();
    if (groupError != null) {
      _announceError(groupError);
      return;
    }

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
        meetingPoint: _meetingController.text.trim(),
        destination: _destinationController.text.trim(),
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
          numMaleTravellers: _numMale,
          numFemaleTravellers: _numFemale,
          scheduledDate: _date!,
          startTime: startTime,
          expectedDurationMinutes: _durationMinutes,
          meetingPoint: _meetingController.text.trim(),
          destination: _destinationController.text.trim(),
          landmark: _emptyToNull(_landmarkController.text),
          purpose: _emptyToNull(_purposeController.text),
          specialNote: _emptyToNull(_noteController.text),
        );
    if (!mounted) return;
    if (id != null) {
      A11y.announce(context, 'Request submitted. TravAcsers in your city are '
          'being notified.');
      _resetForm();
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
    _landmarkController.clear();
    _purposeController.clear();
    _noteController.clear();
    setState(() {
      _numTravellers = 1;
      _numTravAcsers = 1;
      _numMale = 0;
      _numFemale = 1;
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

  String _emptyToNull(String s) => s.trim().isEmpty ? '' : s.trim();
  String _durationLabel() => _durations.entries
      .firstWhere((e) => e.value == _durationMinutes,
          orElse: () => const MapEntry('', 60))
      .key;

  @override
  Widget build(BuildContext context) {
    final my = ref.watch(myProfileProvider).value;
    final busy = ref.watch(requestControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('New Request')),
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
                          _section('Your city: ${my.profile.serviceCity!.label}'),
                          _stepperTile(
                            label: 'Visually impaired travellers',
                            value: _numTravellers,
                            onChanged: _setTravellers,
                            min: 1,
                          ),
                          _stepperTile(
                            label: 'TravAcsers required '
                                '(suggested $_minTravAcsers)',
                            value: _numTravAcsers,
                            min: _minTravAcsers,
                            max: _numTravellers,
                            onChanged: (v) => setState(() => _numTravAcsers =
                                v.clamp(_minTravAcsers, _numTravellers)),
                          ),
                          const SizedBox(height: 8),
                          Text('Gender of travellers '
                              '(must total $_numTravellers)',
                              style: Theme.of(context).textTheme.labelLarge),
                          _stepperTile(
                            label: 'Male travellers',
                            value: _numMale,
                            min: 0,
                            max: _numTravellers,
                            onChanged: (v) => setState(() => _numMale =
                                v.clamp(0, _numTravellers)),
                          ),
                          _stepperTile(
                            label: 'Female travellers',
                            value: _numFemale,
                            min: 0,
                            max: _numTravellers,
                            onChanged: (v) => setState(() => _numFemale =
                                v.clamp(0, _numTravellers)),
                          ),
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
                            controller: _landmarkController,
                            decoration: const InputDecoration(
                                labelText: 'Landmark (optional)'),
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
                            maxLines: 2,
                            decoration: const InputDecoration(
                                labelText: 'Special note / requirement '
                                    '(optional)'),
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

  Widget _stepperTile({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 0,
    int? max,
  }) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > min ? () => onChanged(value - 1) : null,
              tooltip: 'Decrease',
            ),
            SizedBox(
              width: 28,
              child: Text('$value', textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed:
                  (max == null || value < max) ? () => onChanged(value + 1) : null,
              tooltip: 'Increase',
            ),
          ],
        ),
      ),
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
        title: const Text('Start time'),
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
          'Please set your service area (state & city) on the Profile tab '
          'before creating a request.',
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
    required this.meetingPoint,
    required this.destination,
    required this.estimate,
  });

  final DateTime date;
  final String time;
  final String durationLabel;
  final int numTravellers;
  final int numTravAcsers;
  final String meetingPoint;
  final String destination;
  final int estimate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Review your request',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _row('When', '${DateFormat.yMMMEd().format(date)} at $time'),
            _row('Duration', durationLabel),
            _row('Travellers', '$numTravellers'),
            _row('TravAcsers', '$numTravAcsers'),
            _row('Meeting point', meetingPoint),
            _row('Destination', destination),
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
              '(₹${AppConstants.hourlyRateInr}/hour per TravAcser). The final '
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
