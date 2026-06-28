import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import 'auth_controller.dart';

/// Step 2 of phone-OTP login: enter the SMS code. Accessible labeled field with
/// SMS autofill, and an accessible resend control with a cooldown.
class OtpEntryScreen extends ConsumerStatefulWidget {
  const OtpEntryScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpEntryScreen> createState() => _OtpEntryScreenState();
}

class _OtpEntryScreenState extends ConsumerState<OtpEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = AppConstants.otpResendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
      if (_secondsLeft == 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(_controller.text.trim());
    if (!mounted) return;

    if (ok) {
      A11y.announce(context, 'Verified. Signing you in.');
      // Router redirect decides: complete-profile (new user) or role shell.
      context.go('/');
    } else {
      _showError();
    }
  }

  Future<void> _resend() async {
    final ok =
        await ref.read(authControllerProvider.notifier).requestOtp(widget.phone);
    if (!mounted) return;
    if (ok) {
      A11y.announce(context, 'A new code has been sent.');
      _startCooldown();
    } else {
      _showError();
    }
  }

  void _showError() {
    final message = failureMessage(ref.read(authControllerProvider).error);
    A11y.announce(context, message);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);
    final canResend = _secondsLeft == 0 && !isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your number')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Enter the code sent to ${widget.phone}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                // Label comes from InputDecoration; no wrapping Semantics.
                TextFormField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(AppConstants.loginOtpLength),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    hintText: '6-digit code',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.length != AppConstants.loginOtpLength) {
                      return 'Enter the '
                          '${AppConstants.loginOtpLength}-digit code';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => isLoading ? null : _verify(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : _verify,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Verify and continue'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: canResend ? _resend : null,
                  child: Text(
                    canResend
                        ? 'Resend code'
                        : 'Resend code in $_secondsLeft s',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
