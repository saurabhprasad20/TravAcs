import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/profile.dart';
import 'json_converters.dart';

part 'volunteer_profile_dto.freezed.dart';
part 'volunteer_profile_dto.g.dart';

/// DTO for the `volunteer_profiles` table. No Aadhaar fields in v1.
@freezed
abstract class VolunteerProfileDto with _$VolunteerProfileDto {
  const VolunteerProfileDto._();

  const factory VolunteerProfileDto({
    @JsonKey(name: 'profile_id') required String profileId,
    String? address,
    @JsonKey(name: 'verification_status') required String verificationStatus,
    @JsonKey(name: 'rejection_reason') String? rejectionReason,
    @JsonKey(name: 'rating_avg', fromJson: doubleFromJson)
    @Default(0.0)
    double ratingAvg,
    @JsonKey(name: 'rating_count') @Default(0) int ratingCount,
  }) = _VolunteerProfileDto;

  factory VolunteerProfileDto.fromJson(Map<String, dynamic> json) =>
      _$VolunteerProfileDtoFromJson(json);

  VolunteerProfile toEntity() => VolunteerProfile(
        profileId: profileId,
        address: address,
        verificationStatus: VerificationStatus.fromWire(verificationStatus),
        rejectionReason: rejectionReason,
        ratingAvg: ratingAvg,
        ratingCount: ratingCount,
      );
}
