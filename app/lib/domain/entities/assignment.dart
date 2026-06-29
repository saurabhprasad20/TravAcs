import '../../core/util/scheduled_time.dart';
import 'enums.dart';

/// One TravAcser's acceptance of a request (`requests/{id}/assignments/{vid}`).
/// Holds the contact pair (both parties can read their own assignment) plus a
/// denormalized request summary for the TravAcser's "My Trips" list. Trips
/// auto-start at [scheduledStartAt] — there is no OTP (M12).
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
    this.genderPreference = GenderPreference.anyGender,
    this.scheduledStartAt,
    this.volunteerPhone,
    this.requesterPhone,
    this.acceptedAt,
    this.startedAt,
    this.endedAt,
    this.durationMinutes,
    this.amountInr,
    this.paymentStatus = PaymentStatus.pending,
    this.requesterPaidAt,
    this.travAcserReceivedAt,
    this.requesterRatingStars,
    this.requesterRatingFeedback,
    this.volunteerRatingStars,
    this.volunteerRatingFeedback,
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
  /// Absolute instant the trip auto-starts (scheduledDate + startTime). May be
  /// null on legacy docs; use [effectiveStartAt] which falls back.
  final DateTime? scheduledStartAt;
  final int expectedDurationMinutes;
  final String meetingPoint;
  final String destination;
  final GenderPreference genderPreference;
  final int numTravellers;
  final int amountInrEstimate;

  final TripStatus tripStatus;
  final DateTime? acceptedAt;

  // Trip (M5).
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final int? amountInr;

  // Payment + ratings (M6).
  final PaymentStatus paymentStatus;
  final DateTime? requesterPaidAt;
  final DateTime? travAcserReceivedAt;
  final int? requesterRatingStars; // User's rating of the TravAcser
  final String? requesterRatingFeedback;
  final int? volunteerRatingStars; // TravAcser's rating of the User
  final String? volunteerRatingFeedback;

  bool get ratedByRequester => requesterRatingStars != null;
  bool get ratedByVolunteer => volunteerRatingStars != null;

  /// Auto-start anchor: the stored instant, or computed from date + startTime
  /// for legacy docs.
  DateTime get effectiveStartAt =>
      scheduledStartAt ?? combineDateAndTime(scheduledDate, startTime);

  /// In progress once the scheduled start has passed and the trip is still
  /// assigned (time-based auto-start; no OTP, M12).
  bool isInProgress(DateTime now) =>
      tripStatus == TripStatus.assigned && !now.isBefore(effectiveStartAt);

  /// True while the trip still needs attention (My Trips / My Requests).
  bool get isActive => tripStatus.isActive;
}
