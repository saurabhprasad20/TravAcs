import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/config/constants.dart';
import 'package:travacs/domain/entities/assignment.dart';
import 'package:travacs/domain/entities/city.dart';
import 'package:travacs/domain/entities/enums.dart';
import 'package:travacs/domain/entities/profile.dart';
import 'package:travacs/domain/entities/request.dart';

/// Pure-domain unit tests (M10a). No Firebase, no widgets — just the business
/// logic the rest of the app and the Cloud Functions both rely on.
void main() {
  group('Request billing & slots', () {
    test('computeEstimate = hours x rate x TravAcsers, rounded', () {
      // 120 min = 2h, 1 TravAcser -> 2 * 135 = 270.
      expect(Request.computeEstimate(120, 1), 270);
      // 90 min = 1.5h, 2 TravAcsers -> 1.5 * 135 * 2 = 405.
      expect(Request.computeEstimate(90, 2), 405);
      // 50 min, 1 -> round(50/60 * 135) = round(112.5) = 113 (round-half-up).
      expect(Request.computeEstimate(50, 1), 113);
    });

    test('suggestedTravAcsers: one TravAcser assists up to two travellers', () {
      expect(Request.suggestedTravAcsers(0), 1); // guard
      expect(Request.suggestedTravAcsers(1), 1);
      expect(Request.suggestedTravAcsers(2), 1);
      expect(Request.suggestedTravAcsers(3), 2);
      expect(Request.suggestedTravAcsers(4), 2);
      expect(Request.suggestedTravAcsers(5), 3);
    });

    test('slotsRemaining / isFull clamp correctly', () {
      Request r(int acc, int total) => _request(acceptedCount: acc, travAcsers: total);
      expect(r(0, 2).slotsRemaining, 2);
      expect(r(0, 2).isFull, isFalse);
      expect(r(1, 2).slotsRemaining, 1);
      expect(r(2, 2).slotsRemaining, 0);
      expect(r(2, 2).isFull, isTrue);
      // Over-accept can never report negative remaining.
      expect(r(3, 2).slotsRemaining, 0);
      expect(r(3, 2).isFull, isTrue);
    });

    test('durationHours', () {
      expect(_request(durationMinutes: 90).durationHours, 1.5);
    });
  });

  group('Enums round-trip wire <-> value', () {
    test('UserRole fromWire + display label', () {
      expect(UserRole.fromWire('requester'), UserRole.requester);
      expect(UserRole.fromWire('volunteer'), UserRole.volunteer);
      // Wire stays legacy; labels are the renamed user-facing terms.
      expect(UserRole.requester.label, 'User');
      expect(UserRole.volunteer.label, 'TravAcser');
    });

    test('RequestStatus fromWire, isOpen, isCancellable', () {
      expect(RequestStatus.fromWire('broadcast'), RequestStatus.broadcast);
      expect(RequestStatus.broadcast.isOpen, isTrue);
      expect(RequestStatus.assigned.isOpen, isFalse);
      expect(RequestStatus.draft.isCancellable, isTrue);
      expect(RequestStatus.broadcast.isCancellable, isTrue);
      expect(RequestStatus.assigned.isCancellable, isFalse);
    });

    test('TripStatus / PaymentStatus tolerate null with a default', () {
      expect(TripStatus.fromWire(null), TripStatus.assigned);
      expect(TripStatus.fromWire('started'), TripStatus.started);
      expect(PaymentStatus.fromWire(null), PaymentStatus.pending);
      expect(PaymentStatus.fromWire('confirmed'), PaymentStatus.confirmed);
    });

    test('GenderPreference wire round-trip + tolerant default', () {
      for (final g in GenderPreference.values) {
        expect(GenderPreference.fromWire(g.wireValue), g);
        expect(g.label, isNotEmpty);
      }
      expect(GenderPreference.fromWire(null), GenderPreference.anyGender);
      expect(GenderPreference.fromWire('bogus'), GenderPreference.anyGender);
    });

    test('TripStatus active vs terminal', () {
      expect(TripStatus.assigned.isActive, isTrue);
      expect(TripStatus.started.isActive, isTrue);
      expect(TripStatus.completed.isTerminal, isTrue);
      expect(TripStatus.closed.isTerminal, isTrue);
      expect(TripStatus.cancelled.isTerminal, isTrue);
    });

    test('Gender / VerificationStatus fromWire', () {
      expect(Gender.fromWire(null), isNull);
      expect(Gender.fromWire('female'), Gender.female);
      expect(VerificationStatus.fromWire('approved'),
          VerificationStatus.approved);
    });

    test('every enum wireValue round-trips through fromWire', () {
      for (final v in Region.values) {
        expect(Region.fromWire(v.wireValue), v);
      }
      for (final v in RequestStatus.values) {
        expect(RequestStatus.fromWire(v.wireValue), v);
      }
    });
  });

  group('Region / City matching', () {
    test('fromWireOrNull is tolerant', () {
      expect(Region.fromWireOrNull(null), isNull);
      expect(Region.fromWireOrNull('not_a_state'), isNull);
      expect(Region.fromWireOrNull('maharashtra'), Region.maharashtra);
    });

    test('City.forState only returns cities of that state', () {
      final mh = City.forState(Region.maharashtra);
      expect(mh, isNotEmpty);
      expect(mh.every((c) => c.state == Region.maharashtra), isTrue);
      expect(mh.map((c) => c.label), contains('Mumbai'));
    });

    test('Delhi NCR is a single combined city', () {
      expect(City.forState(Region.delhiNcr).length, 1);
      expect(City.fromWire('delhi_ncr')?.label, 'Delhi NCR');
    });

    test('every city wireValue resolves and belongs to a real state', () {
      for (final c in City.all) {
        expect(City.fromWire(c.wireValue), c);
        expect(City.forState(c.state), contains(c));
      }
    });
  });

  group('Profile', () {
    final base = Profile(
      id: 'p1',
      role: UserRole.volunteer,
      fullName: 'Asha',
      serviceArea: Region.delhiNcr,
      serviceCity: City.fromWire('delhi_ncr'),
    );

    test('role getters', () {
      expect(base.isVolunteer, isTrue);
      expect(base.isRequester, isFalse);
      expect(base.hasServiceArea, isTrue);
    });

    test('copyWith overrides only provided fields and keeps id/role', () {
      final updated = base.copyWith(fullName: 'Asha Rao', isActive: false);
      expect(updated.id, 'p1');
      expect(updated.role, UserRole.volunteer);
      expect(updated.fullName, 'Asha Rao');
      expect(updated.isActive, isFalse);
      expect(updated.serviceCity?.label, 'Delhi NCR');
    });

    test('VolunteerProfile.isApproved', () {
      const pending = VolunteerProfile(profileId: 'p1');
      const approved = VolunteerProfile(
          profileId: 'p1', verificationStatus: VerificationStatus.approved);
      expect(pending.isApproved, isFalse);
      expect(approved.isApproved, isTrue);
    });
  });

  group('Assignment rating flags', () {
    test('ratedByRequester / ratedByVolunteer reflect star presence', () {
      final none = _assignment();
      expect(none.ratedByRequester, isFalse);
      expect(none.ratedByVolunteer, isFalse);
      final rated = _assignment(reqStars: 5, volStars: 4);
      expect(rated.ratedByRequester, isTrue);
      expect(rated.ratedByVolunteer, isTrue);
    });
  });

  test('AppConstants sanity', () {
    expect(AppConstants.hourlyRateInr, 135);
    expect(AppConstants.tripOtpLength, 6);
  });
}

Request _request({
  int acceptedCount = 0,
  int travAcsers = 1,
  int durationMinutes = 60,
}) =>
    Request(
      id: 'r1',
      requesterId: 'u1',
      status: RequestStatus.broadcast,
      serviceState: Region.delhiNcr,
      serviceCity: City.fromWire('delhi_ncr')!,
      numTravellers: 1,
      numTravAcsers: travAcsers,
      genderPreference: GenderPreference.anyGender,
      scheduledDate: DateTime(2026, 7, 1),
      startTime: '10:00',
      scheduledStartAt: DateTime(2026, 7, 1, 10, 0),
      expectedDurationMinutes: durationMinutes,
      meetingPoint: 'A',
      destination: 'B',
      estimatedAmountInr: 270,
      acceptedCount: acceptedCount,
    );

Assignment _assignment({int? reqStars, int? volStars}) => Assignment(
      requestId: 'r1',
      volunteerId: 'v1',
      volunteerName: 'V',
      requesterId: 'u1',
      requesterName: 'U',
      scheduledDate: DateTime(2026, 7, 1),
      startTime: '10:00',
      expectedDurationMinutes: 60,
      meetingPoint: 'A',
      destination: 'B',
      numTravellers: 1,
      amountInrEstimate: 135,
      tripStatus: TripStatus.completed,
      requesterRatingStars: reqStars,
      volunteerRatingStars: volStars,
    );
