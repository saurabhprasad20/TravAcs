// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileDto _$ProfileDtoFromJson(Map<String, dynamic> json) => _ProfileDto(
  id: json['id'] as String,
  role: json['role'] as String,
  fullName: json['full_name'] as String,
  gender: json['gender'] as String?,
  dateOfBirth: json['date_of_birth'] as String?,
  phone: json['phone'] as String?,
  isActive: json['is_active'] as bool? ?? true,
);

Map<String, dynamic> _$ProfileDtoToJson(_ProfileDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': instance.role,
      'full_name': instance.fullName,
      'gender': instance.gender,
      'date_of_birth': instance.dateOfBirth,
      'phone': instance.phone,
      'is_active': instance.isActive,
    };
