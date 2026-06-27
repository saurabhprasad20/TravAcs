// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'volunteer_profile_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VolunteerProfileDto {

@JsonKey(name: 'profile_id') String get profileId; String? get address;@JsonKey(name: 'verification_status') String get verificationStatus;@JsonKey(name: 'rejection_reason') String? get rejectionReason;@JsonKey(name: 'rating_avg', fromJson: doubleFromJson) double get ratingAvg;@JsonKey(name: 'rating_count') int get ratingCount;
/// Create a copy of VolunteerProfileDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VolunteerProfileDtoCopyWith<VolunteerProfileDto> get copyWith => _$VolunteerProfileDtoCopyWithImpl<VolunteerProfileDto>(this as VolunteerProfileDto, _$identity);

  /// Serializes this VolunteerProfileDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VolunteerProfileDto&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.address, address) || other.address == address)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.rejectionReason, rejectionReason) || other.rejectionReason == rejectionReason)&&(identical(other.ratingAvg, ratingAvg) || other.ratingAvg == ratingAvg)&&(identical(other.ratingCount, ratingCount) || other.ratingCount == ratingCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,profileId,address,verificationStatus,rejectionReason,ratingAvg,ratingCount);

@override
String toString() {
  return 'VolunteerProfileDto(profileId: $profileId, address: $address, verificationStatus: $verificationStatus, rejectionReason: $rejectionReason, ratingAvg: $ratingAvg, ratingCount: $ratingCount)';
}


}

/// @nodoc
abstract mixin class $VolunteerProfileDtoCopyWith<$Res>  {
  factory $VolunteerProfileDtoCopyWith(VolunteerProfileDto value, $Res Function(VolunteerProfileDto) _then) = _$VolunteerProfileDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'profile_id') String profileId, String? address,@JsonKey(name: 'verification_status') String verificationStatus,@JsonKey(name: 'rejection_reason') String? rejectionReason,@JsonKey(name: 'rating_avg', fromJson: doubleFromJson) double ratingAvg,@JsonKey(name: 'rating_count') int ratingCount
});




}
/// @nodoc
class _$VolunteerProfileDtoCopyWithImpl<$Res>
    implements $VolunteerProfileDtoCopyWith<$Res> {
  _$VolunteerProfileDtoCopyWithImpl(this._self, this._then);

  final VolunteerProfileDto _self;
  final $Res Function(VolunteerProfileDto) _then;

/// Create a copy of VolunteerProfileDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? address = freezed,Object? verificationStatus = null,Object? rejectionReason = freezed,Object? ratingAvg = null,Object? ratingCount = null,}) {
  return _then(_self.copyWith(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,verificationStatus: null == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as String,rejectionReason: freezed == rejectionReason ? _self.rejectionReason : rejectionReason // ignore: cast_nullable_to_non_nullable
as String?,ratingAvg: null == ratingAvg ? _self.ratingAvg : ratingAvg // ignore: cast_nullable_to_non_nullable
as double,ratingCount: null == ratingCount ? _self.ratingCount : ratingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VolunteerProfileDto].
extension VolunteerProfileDtoPatterns on VolunteerProfileDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VolunteerProfileDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VolunteerProfileDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VolunteerProfileDto value)  $default,){
final _that = this;
switch (_that) {
case _VolunteerProfileDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VolunteerProfileDto value)?  $default,){
final _that = this;
switch (_that) {
case _VolunteerProfileDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile_id')  String profileId,  String? address, @JsonKey(name: 'verification_status')  String verificationStatus, @JsonKey(name: 'rejection_reason')  String? rejectionReason, @JsonKey(name: 'rating_avg', fromJson: doubleFromJson)  double ratingAvg, @JsonKey(name: 'rating_count')  int ratingCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VolunteerProfileDto() when $default != null:
return $default(_that.profileId,_that.address,_that.verificationStatus,_that.rejectionReason,_that.ratingAvg,_that.ratingCount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile_id')  String profileId,  String? address, @JsonKey(name: 'verification_status')  String verificationStatus, @JsonKey(name: 'rejection_reason')  String? rejectionReason, @JsonKey(name: 'rating_avg', fromJson: doubleFromJson)  double ratingAvg, @JsonKey(name: 'rating_count')  int ratingCount)  $default,) {final _that = this;
switch (_that) {
case _VolunteerProfileDto():
return $default(_that.profileId,_that.address,_that.verificationStatus,_that.rejectionReason,_that.ratingAvg,_that.ratingCount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'profile_id')  String profileId,  String? address, @JsonKey(name: 'verification_status')  String verificationStatus, @JsonKey(name: 'rejection_reason')  String? rejectionReason, @JsonKey(name: 'rating_avg', fromJson: doubleFromJson)  double ratingAvg, @JsonKey(name: 'rating_count')  int ratingCount)?  $default,) {final _that = this;
switch (_that) {
case _VolunteerProfileDto() when $default != null:
return $default(_that.profileId,_that.address,_that.verificationStatus,_that.rejectionReason,_that.ratingAvg,_that.ratingCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VolunteerProfileDto extends VolunteerProfileDto {
  const _VolunteerProfileDto({@JsonKey(name: 'profile_id') required this.profileId, this.address, @JsonKey(name: 'verification_status') required this.verificationStatus, @JsonKey(name: 'rejection_reason') this.rejectionReason, @JsonKey(name: 'rating_avg', fromJson: doubleFromJson) this.ratingAvg = 0.0, @JsonKey(name: 'rating_count') this.ratingCount = 0}): super._();
  factory _VolunteerProfileDto.fromJson(Map<String, dynamic> json) => _$VolunteerProfileDtoFromJson(json);

@override@JsonKey(name: 'profile_id') final  String profileId;
@override final  String? address;
@override@JsonKey(name: 'verification_status') final  String verificationStatus;
@override@JsonKey(name: 'rejection_reason') final  String? rejectionReason;
@override@JsonKey(name: 'rating_avg', fromJson: doubleFromJson) final  double ratingAvg;
@override@JsonKey(name: 'rating_count') final  int ratingCount;

/// Create a copy of VolunteerProfileDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VolunteerProfileDtoCopyWith<_VolunteerProfileDto> get copyWith => __$VolunteerProfileDtoCopyWithImpl<_VolunteerProfileDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VolunteerProfileDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VolunteerProfileDto&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.address, address) || other.address == address)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.rejectionReason, rejectionReason) || other.rejectionReason == rejectionReason)&&(identical(other.ratingAvg, ratingAvg) || other.ratingAvg == ratingAvg)&&(identical(other.ratingCount, ratingCount) || other.ratingCount == ratingCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,profileId,address,verificationStatus,rejectionReason,ratingAvg,ratingCount);

@override
String toString() {
  return 'VolunteerProfileDto(profileId: $profileId, address: $address, verificationStatus: $verificationStatus, rejectionReason: $rejectionReason, ratingAvg: $ratingAvg, ratingCount: $ratingCount)';
}


}

/// @nodoc
abstract mixin class _$VolunteerProfileDtoCopyWith<$Res> implements $VolunteerProfileDtoCopyWith<$Res> {
  factory _$VolunteerProfileDtoCopyWith(_VolunteerProfileDto value, $Res Function(_VolunteerProfileDto) _then) = __$VolunteerProfileDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'profile_id') String profileId, String? address,@JsonKey(name: 'verification_status') String verificationStatus,@JsonKey(name: 'rejection_reason') String? rejectionReason,@JsonKey(name: 'rating_avg', fromJson: doubleFromJson) double ratingAvg,@JsonKey(name: 'rating_count') int ratingCount
});




}
/// @nodoc
class __$VolunteerProfileDtoCopyWithImpl<$Res>
    implements _$VolunteerProfileDtoCopyWith<$Res> {
  __$VolunteerProfileDtoCopyWithImpl(this._self, this._then);

  final _VolunteerProfileDto _self;
  final $Res Function(_VolunteerProfileDto) _then;

/// Create a copy of VolunteerProfileDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? address = freezed,Object? verificationStatus = null,Object? rejectionReason = freezed,Object? ratingAvg = null,Object? ratingCount = null,}) {
  return _then(_VolunteerProfileDto(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,verificationStatus: null == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as String,rejectionReason: freezed == rejectionReason ? _self.rejectionReason : rejectionReason // ignore: cast_nullable_to_non_nullable
as String?,ratingAvg: null == ratingAvg ? _self.ratingAvg : ratingAvg // ignore: cast_nullable_to_non_nullable
as double,ratingCount: null == ratingCount ? _self.ratingCount : ratingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
