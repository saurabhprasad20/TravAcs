// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'requester_profile_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RequesterProfileDto _$RequesterProfileDtoFromJson(Map<String, dynamic> json) =>
    _RequesterProfileDto(
      profileId: json['profile_id'] as String,
      homeLocationText: json['home_location_text'] as String?,
      ratingAvg:
          json['rating_avg'] == null ? 0.0 : doubleFromJson(json['rating_avg']),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RequesterProfileDtoToJson(
  _RequesterProfileDto instance,
) => <String, dynamic>{
  'profile_id': instance.profileId,
  'home_location_text': instance.homeLocationText,
  'rating_avg': instance.ratingAvg,
  'rating_count': instance.ratingCount,
};
