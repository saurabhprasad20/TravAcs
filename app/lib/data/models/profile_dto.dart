import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/profile.dart';

part 'profile_dto.freezed.dart';
part 'profile_dto.g.dart';

/// Data-transfer object for the `profiles` table. Maps snake_case JSON from
/// PostgREST to/from the pure [Profile] domain entity.
@freezed
abstract class ProfileDto with _$ProfileDto {
  const ProfileDto._();

  const factory ProfileDto({
    required String id,
    required String role,
    @JsonKey(name: 'full_name') required String fullName,
    String? gender,
    @JsonKey(name: 'date_of_birth') String? dateOfBirth,
    String? phone,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
  }) = _ProfileDto;

  factory ProfileDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileDtoFromJson(json);

  Profile toEntity() => Profile(
        id: id,
        role: UserRole.fromWire(role),
        fullName: fullName,
        gender: Gender.fromWire(gender),
        dateOfBirth: dateOfBirth == null ? null : DateTime.parse(dateOfBirth!),
        phone: phone,
        isActive: isActive,
      );
}
