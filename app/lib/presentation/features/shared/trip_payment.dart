import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/razorpay_order.dart';
import '../requester/request_controller.dart';

/// Runs the full Razorpay payment for one completed assignment:
/// create order (server) → open the Razorpay checkout → verify the signature
/// (server) → mark the trip paid. Returns true only if the payment completed
/// and was verified.
///
/// The Razorpay checkout itself offers UPI, cards, GPay, PhonePe, Paytm and
/// wallets; we don't build those buttons ourselves. Payment status changes are
/// announced for screen-reader users.
Future<bool> startTripPayment(
  BuildContext context,
  WidgetRef ref, {
  required String requestId,
  required String volunteerId,
  String? contact,
}) async {
  final controller = ref.read(requestControllerProvider.notifier);

  final order = await controller.createRazorpayOrder(requestId, volunteerId);
  if (!context.mounted) return false;
  if (order == null) {
    _announce(context, failureMessage(ref.read(requestControllerProvider).error));
    return false;
  }

  final result = await _RazorpayCheckout(order, contact: contact).open();
  if (!context.mounted) return false;

  switch (result.kind) {
    case _RzKind.success:
      final ok = await controller.verifyRazorpayPayment(
        requestId: requestId,
        volunteerId: volunteerId,
        razorpayOrderId: result.orderId ?? order.orderId,
        razorpayPaymentId: result.paymentId ?? '',
        razorpaySignature: result.signature ?? '',
      );
      if (!context.mounted) return ok;
      _announce(
        context,
        ok
            ? 'Payment of \u20b9${order.amountInr} successful.'
            : failureMessage(ref.read(requestControllerProvider).error),
      );
      return ok;
    case _RzKind.cancelled:
      _announce(context, 'Payment cancelled. You can pay later from Trip History.');
      return false;
    case _RzKind.error:
      _announce(context, result.message ?? 'Payment failed. Please try again.');
      return false;
  }
}

void _announce(BuildContext context, String msg) {
  A11y.announce(context, msg);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

enum _RzKind { success, cancelled, error }

class _RzResult {
  const _RzResult.success(this.paymentId, this.orderId, this.signature)
      : kind = _RzKind.success,
        message = null;
  const _RzResult.cancelled()
      : kind = _RzKind.cancelled,
        paymentId = null,
        orderId = null,
        signature = null,
        message = null;
  const _RzResult.error(this.message)
      : kind = _RzKind.error,
        paymentId = null,
        orderId = null,
        signature = null;

  final _RzKind kind;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? message;
}

/// Thin wrapper around [Razorpay] that bridges its callback API to a Future.
class _RazorpayCheckout {
  _RazorpayCheckout(this.order, {this.contact});

  final RazorpayOrder order;
  final String? contact;

  final Razorpay _rz = Razorpay();
  final Completer<_RzResult> _completer = Completer<_RzResult>();

  Future<_RzResult> open() {
    _rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _rz.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _rz.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
    try {
      _rz.open(<String, dynamic>{
        'key': order.keyId,
        'order_id': order.orderId,
        'amount': order.amountPaise,
        'currency': order.currency,
        'name': AppConstants.appName,
        'description': 'TravAcs travel-assistance payment',
        if (contact != null && contact!.isNotEmpty)
          'prefill': {'contact': contact},
      });
    } catch (_) {
      if (!_completer.isCompleted) {
        _completer.complete(
            const _RzResult.error('Could not open the payment screen.'));
      }
    }
    // Razorpay keeps native handlers alive until clear() is called.
    return _completer.future.whenComplete(_rz.clear);
  }

  void _onSuccess(PaymentSuccessResponse r) {
    if (_completer.isCompleted) return;
    _completer.complete(
        _RzResult.success(r.paymentId, r.orderId, r.signature));
  }

  void _onError(PaymentFailureResponse r) {
    if (_completer.isCompleted) return;
    // Code 2 (PAYMENT_CANCELLED) is the user dismissing the sheet.
    _completer.complete(r.code == Razorpay.PAYMENT_CANCELLED
        ? const _RzResult.cancelled()
        : _RzResult.error(r.message ?? 'Payment failed. Please try again.'));
  }

  // An external wallet was selected; a success/error event still follows, so
  // this is intentionally a no-op (registering it silences an SDK warning).
  void _onWallet(ExternalWalletResponse r) {}
}
