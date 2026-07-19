import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/city.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/profile.dart';
import '../auth/auth_controller.dart';
import 'profile_controller.dart';
import '../../providers/messaging_providers.dart';
import '../../providers/profile_providers.dart';

/// The Profile tab — fully functional in this milestone. Shows profile details;
/// volunteers additionally see verification status and an availability toggle.
class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ProfileError(message: failureMessage(e)),
        data: (my) => my == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoTile(label: 'Name', value: my.profile.fullName),
                _InfoTile(label: 'Role', value: my.profile.role.label),
                if (my.profile.phone != null)
                  _InfoTile(label: 'Phone', value: my.profile.phone!),
                if (my.profile.gender != null)
                  _InfoTile(label: 'Gender', value: my.profile.gender!.label),
                _RegionTile(
                  state: my.profile.serviceArea,
                  city: my.profile.serviceCity,
                ),
                Builder(builder: (context) {
                  final avg = my.volunteer?.ratingAvg ?? my.requester?.ratingAvg ?? 0;
                  final count =
                      my.volunteer?.ratingCount ?? my.requester?.ratingCount ?? 0;
                  return _InfoTile(
                    label: 'Rating',
                    value: count > 0
                        ? '$avg★ ($count review${count == 1 ? '' : 's'})'
                        : 'No ratings yet',
                  );
                }),
                if (my.volunteer != null) ...[
                  const Divider(height: 32),
                  _VerificationCard(volunteer: my.volunteer!),
                  const SizedBox(height: 8),
                  _AvailabilityTile(isActive: my.profile.isActive),
                ],
                const Divider(height: 32),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                  onPressed: () async {
                    await ref
                        .read(messagingRepositoryProvider)
                        .unregisterToken();
                    await ref.read(authControllerProvider.notifier).signOut();
                  },
                ),
              ],
            ),
      ),
    );
  }
}

/// Error state for the Profile tab: shows the mapped message with Retry / Sign
/// out so a failed profile fetch never leaves an infinite spinner.
class _ProfileError extends ConsumerWidget {
  const _ProfileError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(myProfileProvider),
              child: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ref.read(messagingRepositoryProvider).unregisterToken();
                await ref.read(authControllerProvider.notifier).signOut();
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: Theme.of(context).textTheme.labelMedium),
        subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

/// Editable service-area row (state + city). Tapping opens a picker; saving
/// updates the profile via `setServiceArea`. Shows "Not set" for legacy
/// accounts.
class _RegionTile extends ConsumerWidget {
  const _RegionTile({required this.state, required this.city});
  final Region? state;
  final City? city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = (city != null && state != null)
        ? '${city!.label}, ${state!.label}'
        : 'Not set';
    final busy = ref.watch(profileControllerProvider).isLoading;
    return Semantics(
      button: true,
      label: 'Your city / location: $value. Double tap to change.',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Your city / location',
            style: Theme.of(context).textTheme.labelMedium),
        subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
        trailing: const Icon(Icons.edit_outlined),
        enabled: !busy,
        onTap: () => _pick(context, ref),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<(Region, City)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _RegionPickerSheet(initialState: state, initialCity: city),
    );
    if (result == null) return;
    final notifier = ref.read(profileControllerProvider.notifier);
    final ok = await notifier.setServiceArea(result.$1, result.$2);
    if (!context.mounted) return;
    if (ok) {
      A11y.announce(context, 'Location set to ${result.$2.label}.');
    } else {
      final msg = failureMessage(ref.read(profileControllerProvider).error);
      A11y.announce(context, msg);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

/// Bottom-sheet picker: choose a state, then a city within it, then Save.
class _RegionPickerSheet extends StatefulWidget {
  const _RegionPickerSheet({this.initialState, this.initialCity});
  final Region? initialState;
  final City? initialCity;

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  Region? _state;
  City? _city;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _city = widget.initialCity;
  }

  @override
  Widget build(BuildContext context) {
    final cities = _state == null ? const <City>[] : City.forState(_state!);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text('Select your city / location',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              DropdownButtonFormField<Region>(
                value: _state,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'State'),
                items: Region.options
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r.label)))
                    .toList(),
                onChanged: (r) => setState(() {
                  _state = r;
                  _city = null;
                }),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: cities.isEmpty
                    ? const Center(child: Text('Pick a state first'))
                    : ListView(
                        children: [
                          for (final c in cities)
                            RadioListTile<City>(
                              value: c,
                              groupValue: _city,
                              title: Text(c.label),
                              onChanged: (v) => setState(() => _city = v),
                            ),
                        ],
                      ),
              ),
              FilledButton(
                onPressed: (_state != null && _city != null)
                    ? () => Navigator.pop(context, (_state!, _city!))
                    : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.volunteer});
  final VolunteerProfile volunteer;

  @override
  Widget build(BuildContext context) {
    final status = volunteer.verificationStatus;
    final (icon, color) = switch (status) {
      VerificationStatus.approved => (Icons.verified, Colors.green),
      VerificationStatus.pending => (Icons.hourglass_top, Colors.orange),
      VerificationStatus.rejected => (Icons.cancel, Colors.red),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Verification status: ${status.label}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              switch (status) {
                VerificationStatus.approved =>
                  'You are verified. You can view and accept assistance '
                      'requests.',
                VerificationStatus.pending =>
                  'Your details are awaiting verification by the TravAcs team. '
                      'To request verification, contact us at '
                      '${AppConstants.supportEmail} or '
                      '${AppConstants.supportPhone}. You will get a '
                      'notification once you are approved.',
                VerificationStatus.rejected => volunteer.rejectionReason == null
                    ? 'Your verification was rejected. Please contact the '
                        'TravAcs team at ${AppConstants.supportEmail} or '
                        '${AppConstants.supportPhone}.'
                    : 'Rejected: ${volunteer.rejectionReason}',
              },
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityTile extends ConsumerWidget {
  const _AvailabilityTile({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(profileControllerProvider).isLoading;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Available for requests'),
      subtitle: Text(isActive ? 'You are visible to users' : 'Hidden'),
      value: isActive,
      onChanged: busy
          ? null
          : (value) async {
              final ok = await ref
                  .read(profileControllerProvider.notifier)
                  .setAvailability(value);
              if (!context.mounted) return;
              if (ok) {
                A11y.announce(
                  context,
                  value ? 'You are now available.' : 'You are now unavailable.',
                );
              } else {
                // The switch silently snaps back on failure — a sighted user
                // sees it, but a TalkBack user gets nothing unless we say so.
                final msg =
                    failureMessage(ref.read(profileControllerProvider).error);
                A11y.announce(context, msg);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(msg)));
              }
            },
    );
  }
}
