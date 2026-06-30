import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';

/// "Need help? Contact us" — placeholder support details (replace before store
/// release). Email/phone are selectable + copyable; no external launcher yet.
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
            Text('Need help?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Reach our support team and we’ll usually reply within one '
                'working day.'),
            const SizedBox(height: 24),
            _ContactRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: AppConstants.supportEmail,
            ),
            const SizedBox(height: 16),
            _ContactRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: AppConstants.supportPhone,
            ),
            const SizedBox(height: 24),
            Text(
              'These contact details are placeholders for now and will be '
              'updated before launch.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                SelectableText(value,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy $label',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                A11y.announce(context, '$label copied.');
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(content: Text('$label copied.')));
              }
            },
          ),
        ],
      ),
    );
  }
}

/// A simple scrollable "long text" info page (Terms / Privacy placeholders).
class _PolicyScreen extends StatelessWidget {
  const _PolicyScreen({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Draft — placeholder content to be finalised before store '
                'release.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(intro, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            for (final (heading, body) in sections) ...[
              Semantics(
                header: true,
                child: Text(heading,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 4),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
            ],
          ],
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
      intro:
          'By using ${AppConstants.appName} you agree to these terms. This is '
          'placeholder text outlining the intended terms of service.',
      sections: [
        (
          'Using the service',
          '${AppConstants.appName} connects Users who need travel assistance '
              'with verified TravAcsers. You agree to provide accurate '
              'information and to treat the other party with respect.'
        ),
        (
          'Payments',
          'Assistance is charged at the published hourly rate. Payment is '
              'settled directly between the User and the TravAcser; the app '
              'records confirmations from both sides.'
        ),
        (
          'Conduct & safety',
          'Misuse, harassment, or unsafe behaviour may lead to suspension. '
              'TravAcsers are verified before they can accept requests.'
        ),
        (
          'Liability',
          'The full liability terms will be provided here before the public '
              'release.'
        ),
      ],
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PolicyScreen(
      title: 'Privacy Policy',
      intro:
          'This placeholder describes how ${AppConstants.appName} handles your '
          'data.',
      sections: [
        (
          'What we collect',
          'Your phone number (for sign-in), profile details (name, city, '
              'optional gender/date of birth), trip details you create, and '
              'device notification tokens.'
        ),
        (
          'How it is used',
          'To match Users with TravAcsers in the same city, coordinate trips, '
              'and send notifications. Counterpart contact details are shared '
              'only after a trip is accepted.'
        ),
        (
          'What we do NOT collect',
          'No Aadhaar or identity-document images are stored in this version.'
        ),
        (
          'Diagnostics',
          'Crash and error diagnostics are collected to improve reliability; '
              'they never include the friendly text shown to you.'
        ),
      ],
    );
  }
}
