import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';

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
            Text('Need help?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Reach our support team and we’ll usually reply within one '
                'working day. Please include your registered phone number and '
                'the trip date so we can help you faster.'),
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
            const SizedBox(height: 16),
            _ContactRow(
              icon: Icons.language_outlined,
              label: 'Website',
              value: AppConstants.website,
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
            icon: Icon(Icons.copy_outlined, semanticLabel: 'Copy $label'),
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

/// A simple scrollable "long text" info page (Terms / Privacy).
class _PolicyScreen extends StatelessWidget {
  const _PolicyScreen({
    required this.title,
    required this.intro,
    required this.sections,
    this.footer,
  });

  final String title;
  final String intro;
  final List<(String, String)> sections;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
            if (footer != null)
              Text(footer!, style: Theme.of(context).textTheme.bodySmall),
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
          'Welcome to ${AppConstants.appName}. By creating an account or using '
          'the app you agree to these terms. ${AppConstants.appName} connects '
          'Users who need in-person travel assistance with verified TravAcsers '
          'who provide it for a fee. The service currently operates in India.',
      sections: [
        (
          'Who can use ${AppConstants.appName}',
          'You must be able to enter into a binding agreement to use the app. '
              'Users request assistance for themselves; TravAcsers must complete '
              'verification and be approved before they can accept trips. You '
              'agree to give accurate profile and trip details.'
        ),
        (
          'How a trip works',
          'A User creates a request with the meeting point, destination, date, '
              'time and expected duration. Approved TravAcsers in the same city '
              'can accept it. One TravAcser assists up to two travellers, so a '
              'larger group may be served by more than one TravAcser. When you '
              'meet, the User shares a start code that the TravAcser enters to '
              'begin the trip.'
        ),
        (
          'Pricing',
          'The service charge is ₹${AppConstants.rateSoloInr} per hour when a '
              'TravAcser assists one traveller and ₹${AppConstants.ratePairInr} '
              'per hour when assisting two, plus a flat ₹${AppConstants.travelCostInr} '
              'travel cost per TravAcser. Billing is for a minimum of one hour '
              'and then rounded to the nearest half hour. The estimate shown '
              'when you create a request is indicative; the final amount is '
              'based on the actual trip duration.'
        ),
        (
          'Payment',
          'The trip is billed once it ends. The User makes a single payment for '
              'the whole trip (covering every TravAcser on it) to '
              '${AppConstants.appName} through our payment partner. The team '
              'then passes each TravAcser their share. While the app is in its '
              'test phase a nominal amount of ₹1 is collected at checkout even '
              'though the full computed amount is shown.'
        ),
        (
          'Rescheduling & cancellation',
          'Before a trip starts, a User may reschedule it to a nearby day or '
              'cancel it; an assigned TravAcser is asked to confirm a new time. '
              'Once a trip has started it can no longer be cancelled or '
              'rescheduled — only ended. A User cannot create a new request '
              'while a trip is in progress or a payment is still pending.'
        ),
        (
          'Conduct & safety',
          'Treat the other person with courtesy and respect at all times. '
              'Harassment, discrimination, unsafe behaviour, or misuse of '
              'contact details may lead to suspension or removal. Same-gender '
              'assistance can be requested and is honoured where a matching '
              'TravAcser is available.'
        ),
        (
          'Ratings',
          'After a completed trip both sides may rate each other. Ratings help '
              'keep the community safe and reliable; abusive or fake ratings are '
              'not allowed.'
        ),
        (
          'Liability',
          '${AppConstants.appName} is a platform that connects Users and '
              'TravAcsers and is not itself the provider of the assistance. We '
              'work to verify TravAcsers but cannot guarantee any outcome. To '
              'the extent permitted by law, ${AppConstants.appName} is not '
              'liable for the acts of Users or TravAcsers; please use your own '
              'judgement and contact us or local authorities in an emergency.'
        ),
        (
          'Changes to these terms',
          'We may update these terms as the service evolves. Continued use of '
              'the app after an update means you accept the revised terms.'
        ),
      ],
      footer:
          'Questions about these terms? Email ${AppConstants.supportEmail}.',
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
          'Your privacy matters to us. This policy explains what '
          '${AppConstants.appName} collects, how it is used, and the choices '
          'you have. We aim to collect only what we need to run the service.',
      sections: [
        (
          'Information we collect',
          'Your phone number (used to sign in), the profile details you give us '
              '(name, city, and optionally gender and date of birth), the trip '
              'details you create or accept, ratings, and a device token used to '
              'send you notifications. TravAcsers may also provide an address '
              'for verification.'
        ),
        (
          'How we use your information',
          'To match Users with approved TravAcsers in the same city, to '
              'coordinate and bill trips, to send you trip and account '
              'notifications, and to keep the service safe and reliable. Same-'
              'gender preferences, when set, are used only to decide which '
              'requests a TravAcser can see.'
        ),
        (
          'Sharing between Users and TravAcsers',
          'A User’s and TravAcser’s name and phone number are shared with each '
              'other only after a trip is accepted, so you can coordinate the '
              'meeting. They are not shown to anyone else and are not part of '
              'the public request.'
        ),
        (
          'Payments',
          'Payments are handled by our payment partner (Razorpay). Card and '
              'bank details are entered on their secure checkout and are never '
              'stored by ${AppConstants.appName}. We keep a record of the trip '
              'amount and whether it was paid.'
        ),
        (
          'What we do NOT collect',
          'We do not collect or store Aadhaar or other identity-document images '
              'in this version, and we do not track your location in the '
              'background.'
        ),
        (
          'Diagnostics',
          'We collect crash and error diagnostics to improve reliability. These '
              'contain technical detail only and never include the friendly '
              'messages shown to you or your payment details.'
        ),
        (
          'Data retention & your choices',
          'We keep your account and trip records while your account is active '
              'and as needed for support, safety and legal reasons. To access, '
              'correct or delete your data, contact us at '
              '${AppConstants.supportEmail}. You can turn notifications off from '
              'your device settings.'
        ),
      ],
      footer:
          'Privacy questions? Email ${AppConstants.supportEmail} or visit '
          '${AppConstants.website}.',
    );
  }
}
