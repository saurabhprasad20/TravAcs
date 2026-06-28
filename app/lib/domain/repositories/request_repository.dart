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
    required int numMaleTravellers,
    required int numFemaleTravellers,
    required DateTime scheduledDate,
    required String startTime,
    required int expectedDurationMinutes,
    required String meetingPoint,
    required String destination,
    String? landmark,
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

  /// The OTP the requester shares with the TravAcser [volunteerId] (requester
  /// reads the private secret). Null until accepted / if not permitted.
  Stream<String?> watchShareOtp(String requestId, String volunteerId);

  /// TravAcser starts their trip by verifying the OTP (`startTrip` function).
  FutureResult<Unit> startTrip(String requestId, String otp);

  /// Complete a TravAcser's trip (by that TravAcser or the requester).
  FutureResult<Unit> completeTrip(String requestId, String volunteerId);
}
