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

  /// Billable hours for [durationMinutes] under the company rounding rule:
  ///   • minimum billing is 1 hour;
  ///   • after the first hour, extra minutes past each whole hour round as:
  ///     ≤14 → no charge, 15–40 → +0.5 h, 41–60 → +1 h.
  /// Applies to every subsequent hour (1h14m→1, 1h15m–1h40m→1.5, 1h41m–2h→2).
  static double billedHours(int durationMinutes) {
    if (durationMinutes <= 60) return 1.0;
    final whole = durationMinutes ~/ 60;
    final extra = durationMinutes - whole * 60;
    final add = extra <= 14
        ? 0.0
        : extra <= 40
            ? 0.5
            : 1.0;
    return whole + add;
  }

  /// Per-hour rate for a TravAcser serving [travellersServed] people:
  /// ₹149/hr for one traveller, ₹210/hr for two.
  static int hourlyRateFor(int travellersServed) =>
      travellersServed >= 2 ? AppConstants.ratePairInr : AppConstants.rateSoloInr;

  /// How many of [numTravAcsers] serve two travellers (the "pair" rate) given
  /// [numTravellers] on the trip, distributed as evenly as possible (≤2 each).
  static int pairServingCount(int numTravellers, int numTravAcsers) {
    if (numTravAcsers <= 0) return 0;
    final pair = numTravellers - numTravAcsers;
    return pair.clamp(0, numTravAcsers);
  }

  /// Estimated bill for the whole trip: each TravAcser's billed hours × their
  /// per-head rate (₹149 solo / ₹210 pair), plus ₹100 travel PER TravAcser.
  static int computeEstimate(
      int durationMinutes, int numTravellers, int numTravAcsers) {
    final hours = billedHours(durationMinutes);
    final pair = pairServingCount(numTravellers, numTravAcsers);
    final solo = numTravAcsers - pair;
    final hourlyTotal = pair * AppConstants.ratePairInr + solo * AppConstants.rateSoloInr;
    final service = (hours * hourlyTotal).round();
    final travel = AppConstants.travelCostInr * numTravAcsers;
    return service + travel;
  }

  static String _hoursLabel(double hrs) =>
      hrs == hrs.roundToDouble() ? hrs.toStringAsFixed(0) : hrs.toStringAsFixed(1);

  /// Human-readable breakdown of how [estimatedAmountInr] is computed, e.g.
  /// `"1.5 hr · ₹149/hr × 1 + ₹100 travel × 1"`. Shown next to the amount so the
  /// User can see how it is derived.
  String get estimateBreakdown {
    final hrs = billedHours(expectedDurationMinutes);
    final pair = pairServingCount(numTravellers, numTravAcsers);
    final solo = numTravAcsers - pair;
    final parts = <String>[];
    if (solo > 0) parts.add('₹${AppConstants.rateSoloInr}/hr × $solo');
    if (pair > 0) parts.add('₹${AppConstants.ratePairInr}/hr × $pair');
    return '${_hoursLabel(hrs)} hr · ${parts.join(' + ')}'
        ' + ₹${AppConstants.travelCostInr} travel × $numTravAcsers';
  }
}
