import 'city.dart';
import 'enums.dart';

/// Core user profile (design §5.2 `profiles`). Pure domain entity — no
/// framework or SDK dependencies.
class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    this.gender,
    this.dateOfBirth,
    this.phone,
    this.isActive = true,
    this.serviceArea,
    this.serviceCity,
  });

  final String id;
  final UserRole role;
  final String fullName;
  final Gender? gender;
  final DateTime? dateOfBirth;
  final String? phone;
  final bool isActive;

  /// Service **state** (e.g. Delhi NCR, Maharashtra). Nullable for legacy docs.
  final Region? serviceArea;

  /// Service **city** within [serviceArea] — the matching key (a User matches
  /// only TravAcsers in the same city). Nullable for legacy docs.
  final City? serviceCity;

  bool get isRequester => role == UserRole.requester;
  bool get isVolunteer => role == UserRole.volunteer;
  bool get isAdmin => role == UserRole.admin;

  /// True once both state and city are set (required for creating/matching).
  bool get hasServiceArea => serviceArea != null && serviceCity != null;

  Profile copyWith({
    String? fullName,
    Gender? gender,
    DateTime? dateOfBirth,
    String? phone,
    bool? isActive,
    Region? serviceArea,
    City? serviceCity,
  }) {
    return Profile(
      id: id,
      role: role,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      serviceArea: serviceArea ?? this.serviceArea,
      serviceCity: serviceCity ?? this.serviceCity,
    );
  }
}

/// Requester-specific profile (design §5.2 `requester_profiles`).
class RequesterProfile {
  const RequesterProfile({
    required this.profileId,
    this.homeLocationText,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
  });

  final String profileId;
  final String? homeLocationText;
  final double ratingAvg;
  final int ratingCount;
}

/// The signed-in user's complete profile: the base [Profile] plus the
/// role-specific row. Returned by the profile repository; `null` means the
/// user has authenticated but not yet completed registration.
class MyProfile {
  const MyProfile({
    required this.profile,
    this.requester,
    this.volunteer,
  });

  final Profile profile;
  final RequesterProfile? requester;
  final VolunteerProfile? volunteer;
}

/// Volunteer-specific profile (design §5.2 `volunteer_profiles`).
/// No Aadhaar data in v1 — verification is manual/out-of-band.
class VolunteerProfile {
  const VolunteerProfile({
    required this.profileId,
    this.address,
    this.verificationStatus = VerificationStatus.pending,
    this.rejectionReason,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
  });

  final String profileId;
  final String? address;
  final VerificationStatus verificationStatus;
  final String? rejectionReason;
  final double ratingAvg;
  final int ratingCount;

  bool get isApproved => verificationStatus == VerificationStatus.approved;
}
