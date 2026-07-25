import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/domain/entities/razorpay_order.dart';
import 'package:travacs/presentation/features/shared/trip_payment.dart';

/// The Razorpay Standard Checkout options encode our payment UX policy: UPI is
/// shown FIRST with the intent flow (so a tap opens Google Pay / PhonePe / Paytm
/// natively instead of the in-page "collect" box), other methods stay available
/// below, plus timeout / brand / contact prefill.
void main() {
  const order = RazorpayOrder(
    orderId: 'order_test_1',
    keyId: 'rzp_test_key',
    amountPaise: 100,
    amountInr: 1,
    currency: 'INR',
  );

  test('passes the order identity through to Razorpay', () {
    final o = buildCheckoutOptions(order);
    expect(o['key'], 'rzp_test_key');
    expect(o['order_id'], 'order_test_1');
    expect(o['amount'], 100);
    expect(o['currency'], 'INR');
    expect(o['name'], 'TravAcs');
  });

  test('UPI is first in the display sequence (intent + collect flows)', () {
    final o = buildCheckoutOptions(order);
    final display = (o['config'] as Map)['display'] as Map;
    // UPI block is the first shown.
    expect(display['sequence'], ['block.upi']);
    // Other methods are NOT hidden — default blocks remain shown below UPI.
    expect((display['preferences'] as Map)['show_default_blocks'], isTrue);
    final upi = (display['blocks'] as Map)['upi'] as Map;
    final instrument = (upi['instruments'] as List).first as Map;
    expect(instrument['method'], 'upi');
    // Intent flow (redirect to the app) is offered, with a collect fallback,
    // and intent is listed first.
    expect(instrument['flows'], ['intent', 'collect']);
    expect((instrument['flows'] as List).first, 'intent');
  });

  test('sets a checkout timeout and brand theme', () {
    final o = buildCheckoutOptions(order);
    expect(o['timeout'], 300);
    expect((o['theme'] as Map)['color'], isNotNull);
  });

  test('prefills the contact only when provided', () {
    expect(buildCheckoutOptions(order).containsKey('prefill'), isFalse);
    expect(buildCheckoutOptions(order, contact: '').containsKey('prefill'),
        isFalse);
    final withContact = buildCheckoutOptions(order, contact: '+919000000000');
    expect((withContact['prefill'] as Map)['contact'], '+919000000000');
  });
}
