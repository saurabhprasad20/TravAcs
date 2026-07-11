import '../../core/config/constants.dart';
import '../../core/util/scheduled_time.dart';
import '../../core/util/trip_otp.dart';
import 'enums.dart';
import 'request.dart';

/// One TravAcser's acceptance of a request (`requests/{id}/assignments/{vid}`).
/// Holds the contact pair (both parties can read their own assignment) plus a
/// denormalized request summary for the TravAcser's "My Trips" list. A trip
/// starts when the TravAcser validates the User's offline start-code at/after
/// [scheduledStartAt].
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
    this.travelCostInr,
    this.paymentStatus = PaymentStatus.pending,
    this.requesterPaidAt,
    this.travAcserReceivedAt,
    this.rescheduleStatus,
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
  /// Absolute instant the trip is scheduled to begin (scheduledDate + startTime).
  /// May be null on legacy docs; use [effectiveStartAt] which falls back.
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
  /// Flat travel cost billed on this assignment (₹100 on the first-completed
  /// assignment of the trip, otherwise 0/null). Once per trip.
  final int? travelCostInr;

  // Payment + ratings (M6).
  final PaymentStatus paymentStatus;
  final DateTime? requesterPaidAt;
  final DateTime? travAcserReceivedAt;

  /// Reschedule-confirmation state (item 3). `'pending'` while the User has
  /// rescheduled and this TravAcser must confirm; `'confirmed'`/`'declined'`/
  /// `'expired'` otherwise. Null if never rescheduled.
  final String? rescheduleStatus;
  final int? requesterRatingStars; // User's rating of the TravAcser
  final String? requesterRatingFeedback;
  final int? volunteerRatingStars; // TravAcser's rating of the User
  final String? volunteerRatingFeedback;

  bool get ratedByRequester => requesterRatingStars != null;
  bool get ratedByVolunteer => volunteerRatingStars != null;

  /// True while this TravAcser still needs to confirm/decline a rescheduled
  /// trip (item 3).
  bool get needsRescheduleConfirm => rescheduleStatus == 'pending';

  /// Human-readable breakdown of the trip amount, e.g.
  /// `"₹140/hr × 2 hr"` (plus `" + ₹100 travel"` on the assignment that carries
  /// the once-per-trip travel cost). Uses the billed [durationMinutes] once the
  /// trip is completed, otherwise the estimated duration, and shows the charged
  /// (half-hour rounded-up) hours. The single-TravAcser rate applies (this is
  /// one TravAcser's slice of the request).
  String get amountBreakdown {
    final mins = durationMinutes ?? expectedDurationMinutes;
    final hrs = Request.billableHours(mins);
    final hrsLabel =
        hrs == hrs.roundToDouble() ? hrs.toStringAsFixed(0) : hrs.toStringAsFixed(1);
    final base = '₹${AppConstants.hourlyRateInr}/hr × $hrsLabel hr';
    return (travelCostInr ?? 0) > 0
        ? '$base + ₹$travelCostInr travel'
        : base;
  }

  /// Scheduled-start anchor: the stored instant, or computed from date +
  /// startTime for legacy docs.
  DateTime get effectiveStartAt =>
      scheduledStartAt ?? combineDateAndTime(scheduledDate, startTime);

  /// The deterministic 4-digit start code (point 11). The User reads this to the
  /// TravAcser, who enters it to start the trip. Computed identically on both
  /// sides from the shared assignment fields, so no provider is involved.
  String get startOtp => tripStartOtp(
        userPhone: requesterPhone,
        travAcserPhone: volunteerPhone,
        scheduledStartAt: effectiveStartAt,
      );

  /// The trip is "in progress" once it has actually been started via the
  /// start-code handshake (point 11). Time alone no longer starts a trip.
  bool isInProgress(DateTime now) => tripStatus == TripStatus.started;

  /// The window where the start code is shown (User) / entered (TravAcser): the
  /// trip is still `assigned` and the scheduled time has arrived, but it hasn't
  /// been started yet.
  bool awaitingStart(DateTime now) =>
      tripStatus == TripStatus.assigned && !now.isBefore(effectiveStartAt);

  /// True while the trip still needs attention (My Trips / My Requests).
  bool get isActive => tripStatus.isActive;
}
