/// Maps an FCM notification `type` (the `data.type` sent by the Cloud Functions
/// in `firebase/functions/src/index.ts`) to the shell tab index to open when the
/// user taps the notification, given their role.
///
/// This is what makes a notification "deep-link" to the relevant page — e.g. a
/// TravAcser tapping a "Trip rescheduled" notification lands on My Trips, where
/// the Continue / Cancel banner is (item 6). Returns null when there is no
/// sensible target (the app just opens on its current tab).
///
/// Tab order (see `app_shell.dart`):
///   Volunteer: Available(0), My Trips(1), History(2), Profile(3)
///   Requester: Request(0), My Requests(1), History(2), Profile(3)
int? notificationTargetTab(String? type, {required bool isVolunteer}) {
  if (type == null || type.isEmpty) return null;
  if (isVolunteer) {
    switch (type) {
      case 'new_request':
      case 'gender_widened':
        return 0; // Available — a request to consider accepting
      case 'trip_rescheduled': // the User moved the time — confirm/cancel here
      case 'trip_cancelled':
      case 'reschedule_expired':
      case 'trip_started':
        return 1; // My Trips
      case 'trip_completed':
      case 'payment_marked':
        return 2; // History
      case 'verification_result':
        return 3; // Profile
      default:
        return null;
    }
  }
  // Requester.
  switch (type) {
    case 'assignment':
    case 'trip_started':
    case 'trip_completed':
    case 'trip_cancelled':
    case 'trip_rescheduled':
    case 'reschedule_expired':
    case 'no_travacser_cancelled':
    case 'no_travacser_warning':
      return 1; // My Requests
    case 'verification_result':
      return 3; // Profile
    default:
      return null;
  }
}
