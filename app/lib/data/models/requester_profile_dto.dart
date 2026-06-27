import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/profile.dart';
import 'json_converters.dart';

part 'requester_profile_dto.freezed.dart';
part 'requester_profile_dto.g.dart';

/// DTO for the `requester_profiles` table.
@freezed
abstract class RequesterProfileDto with _$RequesterProfileDto {
  const RequesterProfileDto._();

  const factory RequesterProfileDto({
    @JsonKey(name: 'profile_id') required String profileId,
    @JsonKey(name: 'home_location_text') String? homeLocationText,
    @JsonKey(name: 'rating_avg', fromJson: doubleFromJson)
    @Default(0.0)
    double ratingAvg,
    @JsonKey(name: 'rating_count') @Default(0) int ratingCount,
  }) = _RequesterProfileDto;

  factory RequesterProfileDto.fromJson(Map<String, dynamic> json) =>
      _$RequesterProfileDtoFromJson(json);

  RequesterProfile toEntity() => RequesterProfile(
        profileId: profileId,
        homeLocationText: homeLocationText,
        ratingAvg: ratingAvg,
        ratingCount: ratingCount,
      );
}
