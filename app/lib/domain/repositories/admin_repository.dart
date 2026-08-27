import 'package:fpdart/fpdart.dart';

import '../../core/error/result.dart';
import '../entities/enums.dart';
import '../entities/pending_volunteer.dart';
import '../entities/profile.dart';

/// Admin operations (verification). All writes go through admin-only Cloud
/// Functions.
abstract interface class AdminRepository {
  /// Live list of TravAcsers awaiting verification.
  Stream<List<PendingVolunteer>> watchPendingVolunteers();

  /// All normal accounts, used by the admin moderation picker.
  Stream<List<Profile>> watchAccounts();

  /// Approve or reject a TravAcser (calls the `setVerification` function).
  FutureResult<Unit> setVerification(String uid, bool approved, String? reason);

  /// Temporarily bans an account until [bannedUntil], or unbans it when null.
  FutureResult<Unit> setAccountBan(
    String uid, {
    DateTime? bannedUntil,
    String? reason,
  });

  FutureResult<Unit> setTravelCompensation(
    String requestId,
    String volunteerId,
    int travelCostInr,
  );

  FutureResult<Unit> finalizePaymentReview(String requestId);

  /// Log a manually-booked (e.g. phone) trip into the `tripLogs` telemetry
  /// collection via the admin-only `logManualTrip` function. Mirrors the trip
  /// request form plus a free-text list of TravAcser names (item 12).
  FutureResult<Unit> logManualTrip({
    required String userDetails,
    required String travAcserNames,
    required DateTime tripDate,
    required String startTime,
    required int numTravellers,
    required int numTravAcsers,
    required GenderPreference genderPreference,
    required int durationMinutes,
    required String meetingPoint,
    required String destination,
    required int estimatedAmountInr,
    String? note,
  });
}
