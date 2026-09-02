import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/legal/legal_documents.dart';

/// "Need help? Contact us" — support details. Email/phone/website are
/// selectable + copyable.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact us')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Need help?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Reach our support team and we’ll usually reply within one '
              'working day. Please include your registered phone number and '
              'the trip date so we can help you faster.',
            ),
            const SizedBox(height: 24),
            _ContactRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: AppConstants.supportEmail,
              action: _ContactAction.email,
            ),
            const SizedBox(height: 16),
            _ContactRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: AppConstants.supportPhone,
              action: _ContactAction.call,
            ),
            const SizedBox(height: 16),
            _ContactRow(
              icon: Icons.language_outlined,
              label: 'Website',
              value: AppConstants.website,
              action: _ContactAction.web,
            ),
            const SizedBox(height: 24),
            Text(
              'For anything about a live trip — a TravAcser running late, a '
              'safety concern, or a payment problem — call us so we can act '
              'quickly.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// What tapping a contact row does.
enum _ContactAction { call, email, web }

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.action,
  });

  final IconData icon;
  final String label;
  final String value;
  final _ContactAction action;

  /// The verb shown/announced for the action ("Call", "Email", "Open").
  String get _verb => switch (action) {
    _ContactAction.call => 'Call',
    _ContactAction.email => 'Email',
    _ContactAction.web => 'Open',
  };

  IconData get _actionIcon => switch (action) {
    _ContactAction.call => Icons.call,
    _ContactAction.email => Icons.send_outlined,
    _ContactAction.web => Icons.open_in_new,
  };

  /// The launch target for this row.
  Uri get _uri => switch (action) {
    // tel: needs digits (+ optional leading +), no spaces.
    _ContactAction.call => Uri(
      scheme: 'tel',
      path: value.replaceAll(RegExp(r'[^\d+]'), ''),
    ),
    _ContactAction.email => Uri(scheme: 'mailto', path: value),
    _ContactAction.web => Uri.parse(
      value.startsWith('http') ? value : 'https://$value',
    ),
  };

  Future<void> _launch(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(_uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!context.mounted) return;
    if (!opened) {
      // Degrade gracefully (e.g. no dialer/email app): copy the value so the
      // user isn't stuck, and tell them.
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      final msg = 'Could not open $label. $label copied instead.';
      A11y.announce(context, msg);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$_verb $label, $value',
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _launch(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                Icon(_actionIcon, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable policy content loaded from the legal documents bundled with the
/// app. Selectable text lets assistive-technology users copy or inspect clauses.
class _PolicyScreen extends StatelessWidget {
  const _PolicyScreen({
    required this.title,
    required this.assetPath,
    required this.onlineUrl,
  });

  final String title;
  final String assetPath;
  final String onlineUrl;

  Future<void> _openOnline(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(onlineUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The online document could not be opened. The complete document is '
          'available on this screen.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString(assetPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'This document could not be loaded. Please contact support.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openOnline(context),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View current document online'),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: SelectionArea(
                      child: Text(
                        snapshot.data!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PolicyScreen(
      title: 'Terms & Conditions',
      assetPath: LegalDocuments.termsAsset,
      onlineUrl: AppConstants.termsUrl,
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PolicyScreen(
      title: 'Privacy Policy',
      assetPath: LegalDocuments.privacyAsset,
      onlineUrl: AppConstants.privacyPolicyUrl,
    );
  }
}
