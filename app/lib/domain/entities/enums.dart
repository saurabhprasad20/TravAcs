// Domain enums. Each carries the exact `wireValue` used by the Postgres enums
// (design §5.1) so mapping to/from the database is centralized and typo-safe.

enum UserRole {
  requester('requester'),
  volunteer('volunteer'),
  admin('admin');

  const UserRole(this.wireValue);
  final String wireValue;

  static UserRole fromWire(String value) =>
      UserRole.values.firstWhere((e) => e.wireValue == value);

  /// User-facing display name. (Wire values stay 'requester'/'volunteer' so the
  /// database, rules and history are unaffected.)
  String get label => switch (this) {
        UserRole.requester => 'User',
        UserRole.volunteer => 'TravAcser',
        UserRole.admin => 'Admin',
      };
}

enum Gender {
  male('male'),
  female('female'),
  other('other'),
  preferNotToSay('prefer_not_to_say');

  const Gender(this.wireValue);
  final String wireValue;

  static Gender? fromWire(String? value) => value == null
      ? null
      : Gender.values.firstWhere((e) => e.wireValue == value);

  String get label => switch (this) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
        Gender.preferNotToSay => 'Prefer not to say',
      };
}

enum VerificationStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const VerificationStatus(this.wireValue);
  final String wireValue;

  static VerificationStatus fromWire(String value) =>
      VerificationStatus.values.firstWhere((e) => e.wireValue == value);

  String get label => switch (this) {
        VerificationStatus.pending => 'Pending verification',
        VerificationStatus.approved => 'Verified',
        VerificationStatus.rejected => 'Verification rejected',
      };
}

/// Lifecycle of an assistance request (design §4.2).
enum RequestStatus {
  draft('draft', 'Draft'),
  broadcast('broadcast', 'Open'),
  assigned('assigned', 'Assigned'),
  started('started', 'In progress'),
  completed('completed', 'Completed'),
  closed('closed', 'Closed'),
  cancelled('cancelled', 'Cancelled');

  const RequestStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static RequestStatus fromWire(String value) =>
      RequestStatus.values.firstWhere((e) => e.wireValue == value);

  bool get isOpen => this == RequestStatus.broadcast;
  bool get isCancellable =>
      this == RequestStatus.draft || this == RequestStatus.broadcast;
}

/// Service region used for deterministic matching: a request only reaches
/// TravAcsers whose region equals the request's. We cover Delhi NCR as a single
/// combined region (Delhi folded in); other states/UTs are individual options.
/// The same fixed list is used on both the User and TravAcser sides.
enum Region {
  // Delhi NCR is intentionally first (our primary service region).
  delhiNcr('delhi_ncr', 'Delhi NCR'),
  // States (alphabetical).
  andhraPradesh('andhra_pradesh', 'Andhra Pradesh'),
  arunachalPradesh('arunachal_pradesh', 'Arunachal Pradesh'),
  assam('assam', 'Assam'),
  bihar('bihar', 'Bihar'),
  chhattisgarh('chhattisgarh', 'Chhattisgarh'),
  goa('goa', 'Goa'),
  gujarat('gujarat', 'Gujarat'),
  haryana('haryana', 'Haryana'),
  himachalPradesh('himachal_pradesh', 'Himachal Pradesh'),
  jharkhand('jharkhand', 'Jharkhand'),
  karnataka('karnataka', 'Karnataka'),
  kerala('kerala', 'Kerala'),
  madhyaPradesh('madhya_pradesh', 'Madhya Pradesh'),
  maharashtra('maharashtra', 'Maharashtra'),
  manipur('manipur', 'Manipur'),
  meghalaya('meghalaya', 'Meghalaya'),
  mizoram('mizoram', 'Mizoram'),
  nagaland('nagaland', 'Nagaland'),
  odisha('odisha', 'Odisha'),
  punjab('punjab', 'Punjab'),
  rajasthan('rajasthan', 'Rajasthan'),
  sikkim('sikkim', 'Sikkim'),
  tamilNadu('tamil_nadu', 'Tamil Nadu'),
  telangana('telangana', 'Telangana'),
  tripura('tripura', 'Tripura'),
  uttarPradesh('uttar_pradesh', 'Uttar Pradesh'),
  uttarakhand('uttarakhand', 'Uttarakhand'),
  westBengal('west_bengal', 'West Bengal'),
  // Union Territories (alphabetical; Delhi/NCT folded into Delhi NCR above).
  andamanNicobar('andaman_nicobar', 'Andaman & Nicobar Islands'),
  chandigarh('chandigarh', 'Chandigarh'),
  dnhDd('dnh_dd', 'Dadra & Nagar Haveli and Daman & Diu'),
  jammuKashmir('jammu_kashmir', 'Jammu & Kashmir'),
  ladakh('ladakh', 'Ladakh'),
  lakshadweep('lakshadweep', 'Lakshadweep'),
  puducherry('puducherry', 'Puducherry');

  const Region(this.wireValue, this.label);

  /// Database value (snake_case).
  final String wireValue;

  /// User-facing display name.
  final String label;

  /// Ordered list for dropdowns (Delhi NCR first, then states & UTs).
  static const List<Region> options = Region.values;

  static Region fromWire(String value) =>
      Region.values.firstWhere((e) => e.wireValue == value);

  /// Tolerant lookup for legacy/missing docs.
  static Region? fromWireOrNull(String? value) {
    if (value == null) return null;
    for (final e in Region.values) {
      if (e.wireValue == value) return e;
    }
    return null;
  }
}
