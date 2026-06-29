import 'package:fpdart/fpdart.dart';

import '../../core/error/result.dart';
import '../entities/assignment.dart';
import '../entities/city.dart';
import '../entities/enums.dart';
import '../entities/request.dart';

/// Assistance-request data access (design §5–§6). Matching is region-scoped on
/// the city; status transitions beyond create/cancel are handled in M4+.
abstract interface class RequestRepository {
  /// Creates a `broadcast` request and returns its id.
  FutureResult<String> createRequest({
    required Region serviceState,
    required City serviceCity,
    required String requesterName,
    required int numTravellers,
    required int numTravAcsers,
    required GenderPreference genderPreference,
    required DateTime scheduledDate,
    required String startTime,
    required int expectedDurationMinutes,
    required String meetingPoint,
    required String destination,
    String? purpose,
    String? specialNote,
  });

  /// The signed-in requester's own requests, newest first (live).
  Stream<List<Request>> watchMyRequests();

  /// Open (`broadcast`) requests in [city], newest first (live). For approved,
  /// active TravAcsers; the query + rules enforce the region scope.
  Stream<List<Request>> watchAvailableRequests(City city);

  /// Requester cancels their own request before anyone has accepted.
  FutureResult<Unit> cancelRequest(String id);

  /// TravAcser claims a slot (calls the `acceptRequest` Cloud Function).
  FutureResult<Unit> acceptRequest(String requestId);

  /// The signed-in TravAcser's assignments across all requests, newest first.
  Stream<List<Assignment>> watchMyAssignments();

  /// All TravAcsers who have accepted [requestId] (for the requester's view).
  Stream<List<Assignment>> watchRequestAssignments(String requestId);

  /// Requester reschedules the trip (new date + time) before it starts
  /// (`rescheduleTrip` function). Updates the request and all assignments.
  FutureResult<Unit> rescheduleTrip(
    String requestId,
    DateTime scheduledDate,
    String startTime,
  );

  /// Cancel after acceptance (`cancelTrip` function). The server infers the
  /// caller's role: a requester cancels the whole request; a TravAcser releases
  /// just their own slot.
  FutureResult<Unit> cancelTrip(String requestId);

  /// End/complete a TravAcser's trip (by that TravAcser or the requester). Trips
  /// auto-start at the scheduled time, so this is the only manual transition.
  FutureResult<Unit> completeTrip(String requestId, String volunteerId);

  /// The User marks a TravAcser's payment as Paid (two-sided).
  FutureResult<Unit> markPaid(String requestId, String volunteerId);

  /// The TravAcser marks payment Received (two-sided).
  FutureResult<Unit> markReceived(String requestId);

  /// Rate the counterpart (1–5 + optional feedback) for a completed assignment.
  FutureResult<Unit> submitRating(
    String requestId,
    String volunteerId,
    int stars,
    String? feedback,
  );
}
