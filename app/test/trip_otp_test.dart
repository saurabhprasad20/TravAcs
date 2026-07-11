import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/config/constants.dart';
import 'package:travacs/core/util/trip_otp.dart';

/// Tests the deterministic offline trip-start OTP (point 11). The key property
/// is that both parties compute the SAME code from the same inputs, with no
/// provider or server involved.
void main() {
  final start = DateTime.fromMillisecondsSinceEpoch(1783000000000);

  String otp({String? user, String? tra, DateTime? at}) => tripStartOtp(
        userPhone: user ?? '+919760599211',
        travAcserPhone: tra ?? '+919540453060',
        scheduledStartAt: at ?? start,
      );

  test('is exactly the configured number of digits', () {
    expect(otp().length, AppConstants.tripOtpLength);
    expect(RegExp(r'^\d+$').hasMatch(otp()), isTrue);
  });

  test('is deterministic — same inputs give the same code', () {
    expect(otp(), otp());
  });

  test('changes when the scheduled time changes (reschedule)', () {
    final rescheduled = start.add(const Duration(hours: 3));
    expect(otp(at: start), isNot(otp(at: rescheduled)));
  });

  test('differs across different phone pairs', () {
    expect(otp(user: '+919760599211'), isNot(otp(user: '+918178796516')));
  });

  test('phone normalisation: +91 prefix vs bare 10 digits match', () {
    expect(
      otp(user: '+919760599211', tra: '+919540453060'),
      otp(user: '9760599211', tra: '9540453060'),
    );
  });

  test('does not throw on null phones', () {
    expect(() => otp(user: null, tra: null), returnsNormally);
    expect(otp(user: null, tra: null).length, AppConstants.tripOtpLength);
  });
}
