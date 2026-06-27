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
