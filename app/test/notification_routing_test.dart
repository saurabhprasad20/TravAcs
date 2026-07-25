import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/util/notification_routing.dart';

/// Item 6: a tapped notification routes to the relevant tab per role.
/// Volunteer tabs: Available(0), My Trips(1), History(2), Profile(3).
/// Requester tabs: Request(0), My Requests(1), History(2), Profile(3).
void main() {
  group('notificationTargetTab — volunteer', () {
    test('a reschedule takes the TravAcser to My Trips (item 6 core)', () {
      expect(notificationTargetTab('trip_rescheduled', isVolunteer: true), 1);
      expect(notificationTargetTab('reschedule_expired', isVolunteer: true), 1);
      expect(notificationTargetTab('trip_cancelled', isVolunteer: true), 1);
    });

    test('a new/opened request goes to Available', () {
      expect(notificationTargetTab('new_request', isVolunteer: true), 0);
      expect(notificationTargetTab('gender_widened', isVolunteer: true), 0);
    });

    test('completion/payment goes to History; verification to Profile', () {
      expect(notificationTargetTab('trip_completed', isVolunteer: true), 2);
      expect(notificationTargetTab('payment_marked', isVolunteer: true), 2);
      expect(notificationTargetTab('verification_result', isVolunteer: true), 3);
    });
  });

  group('notificationTargetTab — requester', () {
    test('trip lifecycle notifications go to My Requests', () {
      for (final t in [
        'assignment',
        'trip_started',
        'trip_completed',
        'trip_cancelled',
        'trip_rescheduled',
        'reschedule_expired',
        'no_travacser_cancelled',
        'no_travacser_warning',
      ]) {
        expect(notificationTargetTab(t, isVolunteer: false), 1, reason: t);
      }
    });
  });

  test('unknown or empty type yields no target', () {
    expect(notificationTargetTab(null, isVolunteer: true), isNull);
    expect(notificationTargetTab('', isVolunteer: false), isNull);
    expect(notificationTargetTab('mystery', isVolunteer: true), isNull);
  });
}
