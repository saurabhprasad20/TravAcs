import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/profile.dart';
import '../auth/auth_controller.dart';
import 'profile_controller.dart';
import '../../providers/profile_providers.dart';

/// The Profile tab — fully functional in this milestone. Shows profile details;
/// volunteers additionally see verification status and an availability toggle.
class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final my = ref.watch(myProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: my == null
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
                _RegionTile(region: my.profile.serviceArea),
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
                    await ref.read(authControllerProvider.notifier).signOut();
                  },
                ),
              ],
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
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: Theme.of(context).textTheme.labelMedium),
        subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

/// Editable service-region row. Tapping opens a picker; selecting updates the
/// profile via `setRegion`. Shows "Not set" for legacy accounts.
class _RegionTile extends ConsumerWidget {
  const _RegionTile({required this.region});
  final Region? region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = region?.label ?? 'Not set';
    final busy = ref.watch(profileControllerProvider).isLoading;
    return Semantics(
      button: true,
      label: 'Region: $value. Double tap to change.',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Region', style: Theme.of(context).textTheme.labelMedium),
        subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
        trailing: const Icon(Icons.edit_outlined),
        enabled: !busy,
        onTap: () => _pickRegion(context, ref),
      ),
    );
  }

  Future<void> _pickRegion(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<Region>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Select your region',
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final r in Region.options)
                      RadioListTile<Region>(
                        value: r,
                        groupValue: region,
                        title: Text(r.label),
                        onChanged: (v) => Navigator.pop(ctx, v),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == region) return;
    final ok =
        await ref.read(profileControllerProvider.notifier).setRegion(selected);
    if (ok && context.mounted) {
      A11y.announce(context, 'Region set to ${selected.label}.');
    }
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
                  'You can view and accept assistance requests.',
                VerificationStatus.pending =>
                  'An admin will verify your details. You can accept requests '
                      'once approved.',
                VerificationStatus.rejected => volunteer.rejectionReason == null
                    ? 'Your verification was rejected. Please contact support.'
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
              if (ok && context.mounted) {
                A11y.announce(
                  context,
                  value ? 'You are now available.' : 'You are now unavailable.',
                );
              }
            },
    );
  }
}
