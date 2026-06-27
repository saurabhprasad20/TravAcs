// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'volunteer_profile_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VolunteerProfileDto _$VolunteerProfileDtoFromJson(Map<String, dynamic> json) =>
    _VolunteerProfileDto(
      profileId: json['profile_id'] as String,
      address: json['address'] as String?,
      verificationStatus: json['verification_status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      ratingAvg:
          json['rating_avg'] == null ? 0.0 : doubleFromJson(json['rating_avg']),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$VolunteerProfileDtoToJson(
  _VolunteerProfileDto instance,
) => <String, dynamic>{
  'profile_id': instance.profileId,
  'address': instance.address,
  'verification_status': instance.verificationStatus,
  'rejection_reason': instance.rejectionReason,
  'rating_avg': instance.ratingAvg,
  'rating_count': instance.ratingCount,
};
