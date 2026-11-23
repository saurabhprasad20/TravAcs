import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/legal/legal_documents.dart';
import '../../../domain/entities/enums.dart';

Future<AgreementAcceptance> showAgreementDialog(
  BuildContext context, {
  required UserRole initialRole,
}) async {
  final result = await showDialog<AgreementAcceptance>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AgreementDialog(initialRole: initialRole),
  );
  return result!;
}

class _AgreementDialog extends StatefulWidget {
  const _AgreementDialog({required this.initialRole});

  final UserRole initialRole;

  @override
  State<_AgreementDialog> createState() => _AgreementDialogState();
}

class _AgreementDialogState extends State<_AgreementDialog> {
  final _nameController = TextEditingController();
  late UserRole _role = widget.initialRole;
  bool _accepted = false;

  bool get _canSubmit {
    final name = _nameController.text.trim();
    return _accepted &&
        name.isNotEmpty &&
        RegExp('[A-Z]').hasMatch(name) &&
        name == name.toUpperCase();
  }

  Future<void> _openAgreement() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(LegalDocuments.agreementUrl(_role)),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted || opened) return;
    const message =
        'The agreement webpage could not be opened. Please try again or visit '
        'the TravAcs website.';
    A11y.announce(context, message);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(LegalDocuments.agreementTitle(_role)),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.requester,
                      label: Text('User'),
                      icon: Icon(Icons.accessibility_new),
                    ),
                    ButtonSegment(
                      value: UserRole.volunteer,
                      label: Text('TravAcser'),
                      icon: Icon(Icons.volunteer_activism),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (roles) {
                    setState(() {
                      _role = roles.first;
                      _accepted = false;
                    });
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'By using TravAcs, you consent to the applicable agreement, '
                  'Terms & Conditions, Privacy Policy, and all safety and '
                  'service guidelines. Please visit our website to read the '
                  'complete documents before continuing.',
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _openAgreement,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      'Read ${LegalDocuments.agreementTitle(_role)} online',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Full name in CAPITAL LETTERS',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _accepted,
                  onChanged: (value) {
                    setState(() => _accepted = value ?? false);
                  },
                  title: Text(
                    'I agree to the ${LegalDocuments.agreementTitle(_role)}, '
                    'Terms & Conditions, Privacy Policy, and TravAcs '
                    'guidelines.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed:
                _canSubmit
                    ? () => Navigator.of(context).pop(
                      AgreementAcceptance(
                        role: _role,
                        typedName: _nameController.text.trim(),
                      ),
                    )
                    : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
