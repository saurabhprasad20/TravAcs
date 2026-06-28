/// One TravAcser's acceptance of a request (`requests/{id}/assignments/{vid}`).
/// Holds the contact pair (both parties can read their own assignment) plus a
/// denormalized request summary for the TravAcser's "My Trips" list. The
/// trip-start OTP is NOT here — it lives in a requester-only secret.
class Assignment {
  const Assignment({
    required this.requestId,
    required this.volunteerId,
    required this.volunteerName,
    required this.requesterId,
    required this.requesterName,
    required this.scheduledDate,
    required this.startTime,
    required this.expectedDurationMinutes,
    required this.meetingPoint,
    required this.destination,
    required this.numTravellers,
    required this.amountInrEstimate,
    required this.tripStatus,
    this.volunteerPhone,
    this.requesterPhone,
    this.landmark,
    this.acceptedAt,
  });

  final String requestId;
  final String volunteerId;
  final String volunteerName;
  final String? volunteerPhone;
  final String requesterId;
  final String requesterName;
  final String? requesterPhone;

  final DateTime scheduledDate;
  final String startTime;
  final int expectedDurationMinutes;
  final String meetingPoint;
  final String destination;
  final String? landmark;
  final int numTravellers;
  final int amountInrEstimate;

  /// 'assigned' | 'started' | 'completed' | 'closed' (formalized in M5).
  final String tripStatus;
  final DateTime? acceptedAt;
}
