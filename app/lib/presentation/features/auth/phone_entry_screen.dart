import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import 'auth_controller.dart';

/// Step 1 of phone-OTP login: enter mobile number. Accessible labeled field,
/// numeric keyboard, India (+91) default dial code (v1 focus).
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  static const String _dialCode = '+91';
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = '$_dialCode${_controller.text.trim()}';

    final ok = await ref.read(authControllerProvider.notifier).requestOtp(phone);
    if (!mounted) return;

    if (ok) {
      A11y.announce(context, 'Verification code sent.');
      context.go('/auth/otp?phone=${Uri.encodeComponent(phone)}');
    } else {
      final shown = failureMessage(ref.read(authControllerProvider).error);
      A11y.announce(context, shown);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(shown)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in to ${AppConstants.appName}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(
                    'Enter your mobile number',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "We'll send a one-time verification code by SMS.",
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                // The field's own InputDecoration label is the accessible name;
                // no wrapping Semantics (that would add a phantom edit field).
                TextFormField(
                  controller: _controller,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixText: '$_dialCode ',
                    hintText: '10-digit number',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.length != 10) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => isLoading ? null : _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Send code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
