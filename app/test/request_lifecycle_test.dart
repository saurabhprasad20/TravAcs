import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/domain/entities/city.dart';
import 'package:travacs/domain/entities/enums.dart';
import 'package:travacs/domain/entities/request.dart';
import 'package:travacs/presentation/features/requester/my_requests_screen.dart';

/// Item 9: a completed trip with a pending payment stays "active" (My Requests)
/// and moves to History only once paid.
void main() {
  final city = City.fromWire('delhi_ncr')!;

  Request req(RequestStatus status, {int? tripAmountInr, DateTime? paidAt}) =>
      Request(
        id: 'r1',
        requesterId: 'u1',
        status: status,
        serviceState: Region.delhiNcr,
        serviceCity: city,
        numTravellers: 1,
        numTravAcsers: 1,
        genderPreference: GenderPreference.anyGender,
        scheduledDate: DateTime(2026, 7, 1),
        startTime: '10:00',
        scheduledStartAt: DateTime(2026, 7, 1, 10, 0),
        expectedDurationMinutes: 60,
        meetingPoint: 'A',
        destination: 'B',
        estimatedAmountInr: 135,
        tripAmountInr: tripAmountInr,
        requesterPaidAt: paidAt,
      );

  group('isActiveRequest / isPaymentPending (item 9)', () {
    test('an in-progress (started) trip is active', () {
      expect(isActiveRequest(req(RequestStatus.started)), isTrue);
      expect(isPaymentPending(req(RequestStatus.started)), isFalse);
    });

    test('a completed-but-unpaid trip is active AND payment pending', () {
      final r = req(RequestStatus.completed, tripAmountInr: 415);
      expect(isActiveRequest(r), isTrue);
      expect(isPaymentPending(r), isTrue);
    });

    test('a completed-and-paid trip is NOT active (moves to history)', () {
      final r = req(RequestStatus.completed,
          tripAmountInr: 415, paidAt: DateTime(2026, 7, 1, 12));
      expect(isActiveRequest(r), isFalse);
      expect(isPaymentPending(r), isFalse);
    });

    test('a completed legacy trip with no total is NOT active', () {
      final r = req(RequestStatus.completed); // tripAmountInr null
      expect(isActiveRequest(r), isFalse);
      expect(isPaymentPending(r), isFalse);
    });

    test('a cancelled trip is not active', () {
      expect(isActiveRequest(req(RequestStatus.cancelled)), isFalse);
    });

    test('a broadcast/assigned trip is active', () {
      expect(isActiveRequest(req(RequestStatus.broadcast)), isTrue);
      expect(isActiveRequest(req(RequestStatus.assigned)), isTrue);
    });
  });
}
