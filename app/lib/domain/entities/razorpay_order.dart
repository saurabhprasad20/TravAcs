/// The data the client needs to open the Razorpay checkout for a trip payment.
/// Returned by the `createRazorpayOrder` Cloud Function; the Key Secret never
/// leaves the server.
class RazorpayOrder {
  const RazorpayOrder({
    required this.orderId,
    required this.keyId,
    required this.amountPaise,
    required this.amountInr,
    required this.currency,
  });

  /// Razorpay order id (`order_...`).
  final String orderId;

  /// Razorpay Key ID (public identifier used to open the checkout).
  final String keyId;

  /// Amount in paise (Razorpay's smallest unit).
  final int amountPaise;

  /// Amount in whole rupees (for display).
  final int amountInr;

  /// ISO currency code (always `INR` here).
  final String currency;
}
