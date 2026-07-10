import 'package:fpdart/fpdart.dart';

import '../../core/error/result.dart';
import '../entities/pending_volunteer.dart';

/// Admin operations (verification). All writes go through admin-only Cloud
/// Functions.
abstract interface class AdminRepository {
  /// Live list of TravAcsers awaiting verification.
  Stream<List<PendingVolunteer>> watchPendingVolunteers();

  /// Approve or reject a TravAcser (calls the `setVerification` function).
  FutureResult<Unit> setVerification(String uid, bool approved, String? reason);

  /// Log a manually-booked (e.g. phone) trip into the `tripLogs` telemetry
  /// collection via the admin-only `logManualTrip` function.
  FutureResult<Unit> logManualTrip({
    required String userDetails,
    required String travAcserDetails,
    required DateTime tripDate,
    String? note,
  });
}
