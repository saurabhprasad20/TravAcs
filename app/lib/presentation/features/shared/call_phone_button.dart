import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/accessibility/announce.dart';

typedef PhoneUriLauncher = Future<bool> Function(Uri uri);
typedef PhoneClipboardWriter = Future<void> Function(String value);

/// Opens the system dialler with the number filled in. Overridable so widget
/// tests can verify the exact `tel:` URI without launching another app.
final phoneUriLauncherProvider = Provider<PhoneUriLauncher>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

final phoneClipboardWriterProvider = Provider<PhoneClipboardWriter>(
  (ref) => (value) => Clipboard.setData(ClipboardData(text: value)),
);

/// An explicit, accessible call action for a trip participant.
///
/// This intentionally opens the dialler instead of placing a direct call. The
/// User or TravAcser can confirm the number and start or cancel the call, and
/// TravAcs does not need the sensitive Android CALL_PHONE permission.
class CallPhoneButton extends ConsumerWidget {
  const CallPhoneButton({
    required this.contactRole,
    required this.contactName,
    required this.phone,
    super.key,
  });

  final String contactRole;
  final String contactName;
  final String phone;

  String get _displayName {
    final name = contactName.trim();
    return name.isEmpty ? contactRole : name;
  }

  String get _spokenContact {
    final name = contactName.trim();
    return name.isEmpty ? contactRole : '$contactRole $name';
  }

  String get _dialNumber => phone.replaceAll(RegExp(r'[^\d+]'), '');

  Future<void> _call(BuildContext context, WidgetRef ref) async {
    var opened = false;
    try {
      opened = await ref.read(phoneUriLauncherProvider)(
        Uri(scheme: 'tel', path: _dialNumber),
      );
    } catch (_) {
      opened = false;
    }
    if (!context.mounted || opened) return;

    var copied = false;
    try {
      await ref.read(phoneClipboardWriterProvider)(phone);
      copied = true;
    } catch (_) {
      copied = false;
    }
    if (!context.mounted) return;
    final message =
        copied
            ? 'The phone app could not be opened. The phone number was copied.'
            : 'The phone app could not be opened. The number is $phone.';
    A11y.announce(context, message);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spokenNumber = _dialNumber.split('').join(' ');
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Call $_spokenContact, phone $spokenNumber',
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _dialNumber.isEmpty ? null : () => _call(context, ref),
          icon: const Icon(Icons.call_outlined),
          label: Text('Call $_displayName · $phone'),
        ),
      ),
    );
  }
}
