import 'package:fpdart/fpdart.dart';

import '../../core/error/result.dart';
import '../entities/assignment.dart';
import '../entities/city.dart';
import '../entities/enums.dart';
import '../entities/razorpay_order.dart';
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
    Gender? requesterGender,
    String? purpose,
    String? specialNote,
  });

  /// The signed-in requester's own requests, newest first (live).
  Stream<List<Request>> watchMyRequests();

  /// Open (`broadcast`) requests in [city], newest first (live). For approved,
  /// active TravAcsers; the query + rules enforce the region scope.
  Stream<List<Request>> watchAvailableRequests(City city);

  /// All active (broadcast / assigned / started) requests across the platform,
  /// soonest first — for the admin monitoring dashboard. Rules restrict this to
  /// admins.
  Stream<List<Request>> watchActiveTrips();

  /// Requester cancels their own request before anyone has accepted.
  FutureResult<Unit> cancelRequest(String id);

  /// TravAcser claims a slot (calls the `acceptRequest` Cloud Function).
  FutureResult<Unit> acceptRequest(String requestId);

  /// The signed-in TravAcser's assignments across all requests, newest first.
  Stream<List<Assignment>> watchMyAssignments();

  /// The signed-in requester's assignments across all their requests (via a
  /// collection-group query). Used to detect unpaid completed trips (dues).
  Stream<List<Assignment>> watchMyRequesterAssignments();

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

  /// The TravAcser responds to a rescheduled trip: continue (keep the slot) or
  /// cancel (release it and reopen the request). `respondReschedule` function.
  FutureResult<Unit> respondReschedule(String requestId, bool accept);

  /// End/complete a TravAcser's trip (by that TravAcser or the requester). Only
  /// valid once the trip has been started via the start-code handshake.
  FutureResult<Unit> completeTrip(String requestId, String volunteerId);

  /// Start a trip after the TravAcser validates the User's start code (point 11).
  /// Flips the assignment to `started` ("In progress"). TravAcser-only, and only
  /// once the scheduled time has arrived.
  FutureResult<Unit> startTrip(String requestId, String volunteerId);

  /// The User marks a TravAcser's payment as Paid (two-sided).
  FutureResult<Unit> markPaid(String requestId, String volunteerId);

  /// Creates a Razorpay order for a completed assignment's amount (requester
  /// only). The client opens the checkout with the returned order + key id.
  FutureResult<RazorpayOrder> createRazorpayOrder(
    String requestId,
    String volunteerId,
  );

  /// Verifies a Razorpay payment (signature) server-side and marks the
  /// assignment paid on success.
  FutureResult<Unit> verifyRazorpayPayment({
    required String requestId,
    required String volunteerId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });

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
