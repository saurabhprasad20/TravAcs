import '../../core/config/constants.dart';
import 'city.dart';
import 'enums.dart';

/// An assistance request created by a User (design §5; fields per
/// userRequestForm.txt). Matching is on [serviceCity]. Contact details of the
/// counterpart are added server-side only after assignment (M4), so they are
/// not part of the broadcast view.
class Request {
  const Request({
    required this.id,
    required this.requesterId,
    required this.status,
    required this.serviceState,
    required this.serviceCity,
    required this.numTravellers,
    required this.numTravAcsers,
    required this.genderPreference,
    required this.scheduledDate,
    required this.startTime,
    required this.scheduledStartAt,
    required this.expectedDurationMinutes,
    required this.meetingPoint,
    required this.destination,
    required this.estimatedAmountInr,
    this.acceptedCount = 0,
    this.purpose,
    this.specialNote,
    this.volunteerId,
    this.requesterName,
    this.createdAt,
  });

  final String id;
  final String requesterId;
  final String? volunteerId;
  final RequestStatus status;

  // Matching.
  final Region serviceState;
  final City serviceCity;

  // Group. Only the initiating User's details are kept; [numTravellers] is the
  // total in the party (the initiator is the sole payer).
  final int numTravellers;
  final int numTravAcsers;

  /// The User's gender preference for their TravAcser (informational; matching
  /// itself stays city-based).
  final GenderPreference genderPreference;

  // When.
  final DateTime scheduledDate; // date only
  final String startTime; // HH:mm
  final DateTime scheduledStartAt; // scheduledDate + startTime; auto-start anchor
  final int expectedDurationMinutes;

  // Where / what.
  final String meetingPoint;
  final String destination;
  final String? purpose;
  final String? specialNote;

  // Money (snapshot of the estimate at creation).
  final int estimatedAmountInr;

  /// How many TravAcser slots are filled (slot-filling accept).
  final int acceptedCount;

  int get slotsRemaining =>
      (numTravAcsers - acceptedCount).clamp(0, numTravAcsers);
  bool get isFull => acceptedCount >= numTravAcsers;

  // Display convenience (set on the requester's own reads).
  final String? requesterName;

  final DateTime? createdAt;

  double get durationHours => expectedDurationMinutes / 60.0;

  /// Minimum TravAcsers for [travellers] (one TravAcser assists up to 2 users).
  static int suggestedTravAcsers(int travellers) =>
      travellers <= 0 ? 1 : ((travellers + 1) ~/ 2);

  /// Estimated bill: hours × hourly rate × number of TravAcsers.
  static int computeEstimate(int durationMinutes, int numTravAcsers) =>
      (durationMinutes / 60.0 * AppConstants.hourlyRateInr * numTravAcsers)
          .round();
}
