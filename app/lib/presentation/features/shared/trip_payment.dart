import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/config/constants.dart';
import '../../../core/error/error_reporter.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/razorpay_order.dart';
import '../requester/request_controller.dart';

/// Runs the full Razorpay payment for a completed trip:
/// create order (server) → open the Razorpay checkout → verify the signature
/// (server) → mark the whole trip paid. Returns true only if the payment
/// completed and was verified.
///
/// The Razorpay checkout itself offers UPI, cards, GPay, PhonePe, Paytm and
/// wallets; we don't build those buttons ourselves. Payment status changes are
/// announced for screen-reader users.
///
/// IMPORTANT: verification must NOT depend on a live widget context. Ending the
/// trip commits server-side immediately, which can rebuild/remove the calling
/// widget (e.g. the trip-detail body) while the native Razorpay sheet is still
/// open. So we capture the ScaffoldMessenger + TextDirection up front and use
/// the (app-scoped) controller notifier captured before the first await — the
/// signature verification always runs even after the caller unmounts.
Future<bool> startTripPayment(
  BuildContext context,
  WidgetRef ref, {
  required String requestId,
  String? contact,
}) async {
  final controller = ref.read(requestControllerProvider.notifier);
  // Capture context-bound handles BEFORE any await so announcements survive the
  // caller unmounting.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final dir = Directionality.maybeOf(context) ?? TextDirection.ltr;
  void announce(String msg) {
    SemanticsService.announce(msg, dir);
    messenger
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  final order = await controller.createRazorpayOrder(requestId);
  if (order == null) {
    announce(failureMessage(ref.read(requestControllerProvider).error));
    return false;
  }

  final result = await _RazorpayCheckout(order, contact: contact).open();

  switch (result.kind) {
    case _RzKind.success:
      // Always verify — money has been collected; skipping this would leave the
      // trip unpaid despite a successful charge.
      final ok = await controller.verifyRazorpayPayment(
        requestId: requestId,
        razorpayOrderId: result.orderId ?? order.orderId,
        razorpayPaymentId: result.paymentId ?? '',
        razorpaySignature: result.signature ?? '',
      );
      announce(
        ok
            ? 'Payment of \u20b9${order.amountInr} successful.'
            : failureMessage(ref.read(requestControllerProvider).error),
      );
      return ok;
    case _RzKind.cancelled:
      announce('Payment cancelled. You can pay later from Trip History.');
      return false;
    case _RzKind.error:
      // Never surface the raw SDK text to the user (golden rule #1): log it as
      // debug detail and show a curated, accessible message.
      ErrorReporter.reportNonFatal(
        UnexpectedFailure(debugDetail: 'Razorpay: ${result.message ?? 'unknown'}'),
      );
      announce('Payment could not be completed. Please try again.');
      return false;
  }
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
