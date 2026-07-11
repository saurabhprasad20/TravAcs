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
    this.requesterGender,
    this.genderRestricted = false,
    this.genderWidened = false,
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

  /// The requester's own gender, denormalized for gender matching. Null/undisclosed
  /// means no gender restriction can be applied.
  final Gender? requesterGender;

  /// True when this request is limited to same-gender TravAcsers (only for a
  /// `strict_same_gender` preference with a known requester gender) — until it
  /// widens ([genderWidened]).
  final bool genderRestricted;

  /// True once a gender-restricted request has been auto-widened to all genders
  /// (near the scheduled time). Set by the `widenGenderRequests` function.
  final bool genderWidened;

  // When.
  final DateTime scheduledDate; // date only
  final String startTime; // HH:mm
  final DateTime scheduledStartAt; // scheduledDate + startTime; schedule anchor
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

  /// Number of billable 30-minute blocks for [durationMinutes], rounded UP to
  /// the next half hour (minimum one block). A 4h58m trip → 10 blocks (5h).
  static int billingBlocks(int durationMinutes) {
    if (durationMinutes <= 0) return 1;
    final blocks =
        (durationMinutes + AppConstants.billingBlockMinutes - 1) ~/
            AppConstants.billingBlockMinutes;
    return blocks < 1 ? 1 : blocks;
  }

  /// Billable hours (blocks × 0.5) for [durationMinutes], after the half-hour
  /// round-up. Used to display the charged duration.
  static double billableHours(int durationMinutes) =>
      billingBlocks(durationMinutes) / 2.0;

  /// Service charge (one TravAcser's time) for [durationMinutes]: billed at the
  /// hourly rate in 30-minute blocks rounded UP to the next half hour, i.e.
  /// `₹70 × ceil(minutes / 30)`.
  static int serviceCharge(int durationMinutes) =>
      billingBlocks(durationMinutes) * (AppConstants.hourlyRateInr ~/ 2);

  /// Estimated bill: the per-TravAcser service charge × number of TravAcsers,
  /// plus a single flat travel cost for the whole trip.
  static int computeEstimate(int durationMinutes, int numTravAcsers) =>
      serviceCharge(durationMinutes) * numTravAcsers +
      AppConstants.travelCostInr;

  /// Human-readable breakdown of how [estimatedAmountInr] is computed, e.g.
  /// `"₹140/hr × 5 hr + ₹100 travel"` (or `"× 2 TravAcsers"` when more than
  /// one). Shown next to the amount so the User can see how it is derived.
  String get estimateBreakdown {
    final hrs = billableHours(expectedDurationMinutes);
    final hrsLabel =
        hrs == hrs.roundToDouble() ? hrs.toStringAsFixed(0) : hrs.toStringAsFixed(1);
    final perCount = numTravAcsers == 1
        ? ''
        : ' × $numTravAcsers TravAcsers';
    return '₹${AppConstants.hourlyRateInr}/hr × $hrsLabel hr$perCount'
        ' + ₹${AppConstants.travelCostInr} travel';
  }
}
