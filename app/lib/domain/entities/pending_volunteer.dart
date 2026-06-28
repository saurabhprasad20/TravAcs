import 'city.dart';
import 'enums.dart';

/// A TravAcser awaiting admin verification (read by admins from `profiles`).
class PendingVolunteer {
  const PendingVolunteer({
    required this.uid,
    required this.fullName,
    this.phone,
    this.address,
    this.state,
    this.city,
    this.gender,
    this.dateOfBirth,
  });

  final String uid;
  final String fullName;
  final String? phone;
  final String? address;
  final Region? state;
  final City? city;
  final Gender? gender;
  final DateTime? dateOfBirth;
}
