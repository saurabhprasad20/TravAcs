import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  bool get _canSubmit {
    final name = _nameController.text.trim();
    return name.isNotEmpty &&
        RegExp('[A-Z]').hasMatch(name) &&
        name == name.toUpperCase();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose your role, read the agreement, then type your full '
                'name in CAPITAL LETTERS to confirm.',
              ),
              const SizedBox(height: 12),
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
                  setState(() => _role = roles.first);
                },
              ),
              const SizedBox(height: 12),
              Semantics(
                label: '${LegalDocuments.agreementTitle(_role)} text',
                child: Container(
                  height: 280,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FutureBuilder<String>(
                    future: rootBundle.loadString(
                      LegalDocuments.agreementAsset(_role),
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return const Center(
                          child: Text(
                            'The agreement could not be loaded. Please contact '
                            'support.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        child: SelectionArea(child: Text(snapshot.data!)),
                      );
                    },
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
                  helperText:
                      'Submit is enabled only when the name is in capitals.',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
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
            child: const Text('Submit and proceed'),
          ),
        ],
      ),
    );
  }
}
