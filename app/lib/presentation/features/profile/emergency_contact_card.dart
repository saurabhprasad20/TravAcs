import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmergencyContactCard extends StatelessWidget {
  const EmergencyContactCard({
    required this.nameController,
    required this.relationController,
    required this.phoneController,
    this.hint = 'You can provide it later.',
    this.initiallyExpanded = false,
    this.expansionController,
    this.enabled = true,
    this.onSave,
    super.key,
  });

  final TextEditingController nameController;
  final TextEditingController relationController;
  final TextEditingController phoneController;
  final String hint;
  final bool initiallyExpanded;
  final ExpansionTileController? expansionController;
  final bool enabled;
  final VoidCallback? onSave;

  bool get _hasAnyValue =>
      nameController.text.trim().isNotEmpty ||
      relationController.text.trim().isNotEmpty ||
      phoneController.text.trim().isNotEmpty;

  String? _requiredWhenStarted(String? value, String label) {
    if (!_hasAnyValue || (value?.trim().isNotEmpty ?? false)) return null;
    return 'Please enter the emergency contact $label';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        controller: expansionController,
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        title: const Text('Emergency contact (optional)'),
        subtitle: Text(hint),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextFormField(
            key: const ValueKey('emergency-contact-name'),
            controller: nameController,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            maxLines: 1,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Contact name'),
            validator: (value) => _requiredWhenStarted(value, 'name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('emergency-contact-relation'),
            controller: relationController,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            maxLines: 1,
            maxLength: 50,
            decoration: const InputDecoration(
              labelText: 'Relation',
              hintText: 'For example, parent, sibling, or friend',
            ),
            validator: (value) => _requiredWhenStarted(value, 'relation'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('emergency-contact-phone'),
            controller: phoneController,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLines: 1,
            maxLength: 15,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              helperText: 'Enter 7 to 15 digits without spaces.',
            ),
            validator: (value) {
              final required = _requiredWhenStarted(value, 'phone number');
              if (required != null) return required;
              final phone = value?.trim() ?? '';
              if (phone.isNotEmpty && phone.length < 7) {
                return 'Enter at least 7 digits';
              }
              return null;
            },
          ),
          if (onSave != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: enabled ? onSave : null,
                child: const Text('Save emergency contact'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
