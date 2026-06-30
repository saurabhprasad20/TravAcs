import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/pending_volunteer.dart';
import '../../providers/admin_providers.dart';
import '../menu/app_menu_drawer.dart';
import 'admin_controller.dart';

/// In-app admin panel — approve/reject pending TravAcsers (admin claim only).
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingVolunteersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Verifications')),
      drawer: const AppMenuDrawer(),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(failureMessage(e)),
        ),
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
