// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'requester_profile_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RequesterProfileDto {

@JsonKey(name: 'profile_id') String get profileId;@JsonKey(name: 'home_location_text') String? get homeLocationText;@JsonKey(name: 'rating_avg', fromJson: doubleFromJson) double get ratingAvg;@JsonKey(name: 'rating_count') int get ratingCount;
/// Create a copy of RequesterProfileDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RequesterProfileDtoCopyWith<RequesterProfileDto> get copyWith => _$RequesterProfileDtoCopyWithImpl<RequesterProfileDto>(this as RequesterProfileDto, _$identity);

  /// Serializes this RequesterProfileDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RequesterProfileDto&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.homeLocationText, homeLocationText) || other.homeLocationText == homeLocationText)&&(identical(other.ratingAvg, ratingAvg) || other.ratingAvg == ratingAvg)&&(identical(other.ratingCount, ratingCount) || other.ratingCount == ratingCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,profileId,homeLocationText,ratingAvg,ratingCount);

@override
String toString() {
  return 'RequesterProfileDto(profileId: $profileId, homeLocationText: $homeLocationText, ratingAvg: $ratingAvg, ratingCount: $ratingCount)';
}


}

/// @nodoc
abstract mixin class $RequesterProfileDtoCopyWith<$Res>  {
  factory $RequesterProfileDtoCopyWith(RequesterProfileDto value, $Res Function(RequesterProfileDto) _then) = _$RequesterProfileDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'profile_id') String profileId,@JsonKey(name: 'home_location_text') String? homeLocationText,@JsonKey(name: 'rating_avg', fromJson: doubleFromJson) double ratingAvg,@JsonKey(name: 'rating_count') int ratingCount
});




}
/// @nodoc
class _$RequesterProfileDtoCopyWithImpl<$Res>
    implements $RequesterProfileDtoCopyWith<$Res> {
  _$RequesterProfileDtoCopyWithImpl(this._self, this._then);

  final RequesterProfileDto _self;
  final $Res Function(RequesterProfileDto) _then;

/// Create a copy of RequesterProfileDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? homeLocationText = freezed,Object? ratingAvg = null,Object? ratingCount = null,}) {
  return _then(_self.copyWith(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String,homeLocationText: freezed == homeLocationText ? _self.homeLocationText : homeLocationText // ignore: cast_nullable_to_non_nullable
as String?,ratingAvg: null == ratingAvg ? _self.ratingAvg : ratingAvg // ignore: cast_nullable_to_non_nullable
as double,ratingCount: null == ratingCount ? _self.ratingCount : ratingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RequesterProfileDto].
extension RequesterProfileDtoPatterns on RequesterProfileDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RequesterProfileDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RequesterProfileDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RequesterProfileDto value)  $default,){
final _that = this;
switch (_that) {
case _RequesterProfileDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RequesterProfileDto value)?  $default,){
final _that = this;
switch (_that) {
case _RequesterProfileDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile_id')  String profileId, @JsonKey(name: 'home_location_text')  String? homeLocationText, @JsonKey(name: 'rating_avg', fromJson: doubleFromJson)  double ratingAvg, @JsonKey(name: 'rating_count')  int ratingCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RequesterProfileDto() when $default != null:
return $default(_that.profileId,_that.homeLocationText,_that.ratingAvg,_that.ratingCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile_id')  String profileId, @JsonKey(name: 'home_location_text')  String? homeLocationText, @JsonKey(name: 'rating_avg', fromJson: doubleFromJson)  double ratingAvg, @JsonKey(name: 'rating_count')  int ratingCount)  $default,) {final _that = this;
switch (_that) {
case _RequesterProfileDto():
return $default(_that.profileId,_that.homeLocationText,_that.ratingAvg,_that.ratingCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'profile_id')  String profileId, @JsonKey(name: 'home_location_text')  String? homeLocationText, @JsonKey(name: 'rating_avg', fromJson: doubleFromJson)  double ratingAvg, @JsonKey(name: 'rating_count')  int ratingCount)?  $default,) {final _that = this;
switch (_that) {
case _RequesterProfileDto() when $default != null:
return $default(_that.profileId,_that.homeLocationText,_that.ratingAvg,_that.ratingCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RequesterProfileDto extends RequesterProfileDto {
  const _RequesterProfileDto({@JsonKey(name: 'profile_id') required this.profileId, @JsonKey(name: 'home_location_text') this.homeLocationText, @JsonKey(name: 'rating_avg', fromJson: doubleFromJson) this.ratingAvg = 0.0, @JsonKey(name: 'rating_count') this.ratingCount = 0}): super._();
  factory _RequesterProfileDto.fromJson(Map<String, dynamic> json) => _$RequesterProfileDtoFromJson(json);

@override@JsonKey(name: 'profile_id') final  String profileId;
@override@JsonKey(name: 'home_location_text') final  String? homeLocationText;
@override@JsonKey(name: 'rating_avg', fromJson: doubleFromJson) final  double ratingAvg;
@override@JsonKey(name: 'rating_count') final  int ratingCount;

/// Create a copy of RequesterProfileDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequesterProfileDtoCopyWith<_RequesterProfileDto> get copyWith => __$RequesterProfileDtoCopyWithImpl<_RequesterProfileDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RequesterProfileDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequesterProfileDto&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.homeLocationText, homeLocationText) || other.homeLocationText == homeLocationText)&&(identical(other.ratingAvg, ratingAvg) || other.ratingAvg == ratingAvg)&&(identical(other.ratingCount, ratingCount) || other.ratingCount == ratingCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,profileId,homeLocationText,ratingAvg,ratingCount);

@override
String toString() {
  return 'RequesterProfileDto(profileId: $profileId, homeLocationText: $homeLocationText, ratingAvg: $ratingAvg, ratingCount: $ratingCount)';
}


}

/// @nodoc
abstract mixin class _$RequesterProfileDtoCopyWith<$Res> implements $RequesterProfileDtoCopyWith<$Res> {
  factory _$RequesterProfileDtoCopyWith(_RequesterProfileDto value, $Res Function(_RequesterProfileDto) _then) = __$RequesterProfileDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'profile_id') String profileId,@JsonKey(name: 'home_location_text') String? homeLocationText,@JsonKey(name: 'rating_avg', fromJson: doubleFromJson) double ratingAvg,@JsonKey(name: 'rating_count') int ratingCount
});




}
/// @nodoc
class __$RequesterProfileDtoCopyWithImpl<$Res>
    implements _$RequesterProfileDtoCopyWith<$Res> {
  __$RequesterProfileDtoCopyWithImpl(this._self, this._then);

  final _RequesterProfileDto _self;
  final $Res Function(_RequesterProfileDto) _then;

/// Create a copy of RequesterProfileDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? homeLocationText = freezed,Object? ratingAvg = null,Object? ratingCount = null,}) {
  return _then(_RequesterProfileDto(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String,homeLocationText: freezed == homeLocationText ? _self.homeLocationText : homeLocationText // ignore: cast_nullable_to_non_nullable
as String?,ratingAvg: null == ratingAvg ? _self.ratingAvg : ratingAvg // ignore: cast_nullable_to_non_nullable
as double,ratingCount: null == ratingCount ? _self.ratingCount : ratingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
