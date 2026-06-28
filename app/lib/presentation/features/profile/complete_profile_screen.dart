import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/city.dart';
import '../../../domain/entities/enums.dart';
import '../../providers/core_providers.dart';
import 'profile_controller.dart';

/// One-time registration after first phone-OTP sign-in (design §7, §10).
/// Collects role + core profile fields, then creates the profile via
/// `upsert_my_profile`. The router moves the user into the role shell on
/// success.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _homeLocationController = TextEditingController();

  UserRole _role = UserRole.requester;
  Region? _serviceState;
  City? _serviceCity;
  Gender? _gender;
  DateTime? _dob;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _homeLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Select your date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Firebase stores the verified number; prefill it on the profile.
    final phone = ref.read(firebaseAuthProvider).currentUser?.phoneNumber;

    final ok = await ref.read(profileControllerProvider.notifier).save(
          role: _role,
          fullName: _nameController.text.trim(),
          serviceState: _serviceState!,
          serviceCity: _serviceCity!,
          gender: _gender,
          dateOfBirth: _dob,
          phone: phone,
          address: _role == UserRole.volunteer
              ? _addressController.text.trim()
              : null,
          homeLocationText: _role == UserRole.requester
              ? _homeLocationController.text.trim()
              : null,
        );
    if (!mounted) return;

    if (ok) {
      A11y.announce(context, 'Profile created. Welcome to TravAcs.');
    } else {
      final message =
          failureMessage(ref.read(profileControllerProvider).error);
      A11y.announce(context, message);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(profileControllerProvider).isLoading;
    final dobLabel = _dob == null
        ? 'Not set'
        : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-'
            '${_dob!.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text('I am a',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Select your role',
                  child: SegmentedButton<UserRole>(
                    segments: [
                      ButtonSegment(
                        value: UserRole.requester,
                        label: Text(UserRole.requester.label),
                        icon: const Icon(Icons.accessibility_new),
                      ),
                      ButtonSegment(
                        value: UserRole.volunteer,
                        label: Text(UserRole.volunteer.label),
                        icon: const Icon(Icons.volunteer_activism),
                      ),
                    ],
                    selected: {_role},
                    onSelectionChanged: (s) => setState(() => _role = s.first),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _role == UserRole.requester
                      ? 'You request travel assistance.'
                      : 'You provide travel assistance to users.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Region>(
                  value: _serviceState,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'State'),
                  items: Region.options
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          ))
                      .toList(),
                  onChanged: (r) => setState(() {
                    _serviceState = r;
                    _serviceCity = null; // reset dependent city
                  }),
                  validator: (r) =>
                      r == null ? 'Please select your state' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<City>(
                  value: _serviceCity,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    helperText: 'You are matched with people in this city.',
                  ),
                  items: (_serviceState == null
                          ? const <City>[]
                          : City.forState(_serviceState!))
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.label),
                          ))
                      .toList(),
                  onChanged: _serviceState == null
                      ? null
                      : (c) => setState(() => _serviceCity = c),
                  validator: (c) =>
                      c == null ? 'Please select your city' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Gender>(
                  value: _gender,
                  decoration:
                      const InputDecoration(labelText: 'Gender (optional)'),
                  items: Gender.values
                      .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g.label),
                          ))
                      .toList(),
                  onChanged: (g) => setState(() => _gender = g),
                ),
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: 'Date of birth, $dobLabel',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date of birth (optional)'),
                    subtitle: Text(dobLabel),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _pickDob,
                  ),
                ),
                const SizedBox(height: 16),
                if (_role == UserRole.volunteer)
                  TextFormField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.words,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter your address'
                        : null,
                  )
                else
                  TextFormField(
                    controller: _homeLocationController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Home location (optional)',
                    ),
                  ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Create profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
