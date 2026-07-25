import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/domain/entities/razorpay_order.dart';
import 'package:travacs/presentation/features/shared/trip_payment.dart';

/// The Razorpay Standard Checkout options are deliberately minimal so the
/// checkout renders correctly: the amount + enabled methods come from the
/// server `order_id` (no client `amount`, no custom method/display config that
/// could hide UPI or corrupt the sheet). UPI intent redirect is enabled via the
/// Android manifest `<queries>`, not via these options.
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
    expect(o['currency'], 'INR');
    expect(o['name'], 'TravAcs');
  });

  test('does NOT send a client amount or a custom method/display config', () {
    // With an order_id, Razorpay derives the amount + methods server-side.
    // Passing a client amount caused a wrong-amount display; a custom
    // config.display.blocks hid UPI — both must stay out.
    final o = buildCheckoutOptions(order);
    expect(o.containsKey('amount'), isFalse);
    expect(o.containsKey('config'), isFalse);
    expect(o.containsKey('method'), isFalse);
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
