import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/error/supabase_error_mapper.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/profile_dto.dart';
import '../models/requester_profile_dto.dart';
import '../models/volunteer_profile_dto.dart';

/// Supabase-backed [ProfileRepository].
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  FutureResult<MyProfile?> getMyProfile() async {
    final uid = _uid;
    if (uid == null) {
      return failure(const AuthFailure('You are not signed in.'));
    }
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return success(null); // not yet registered

      final profile = ProfileDto.fromJson(row).toEntity();

      RequesterProfile? requester;
      VolunteerProfile? volunteer;

      if (profile.isRequester) {
        final r = await _client
            .from('requester_profiles')
            .select()
            .eq('profile_id', uid)
            .maybeSingle();
        if (r != null) requester = RequesterProfileDto.fromJson(r).toEntity();
      } else if (profile.isVolunteer) {
        final v = await _client
            .from('volunteer_profiles')
            .select()
            .eq('profile_id', uid)
            .maybeSingle();
        if (v != null) volunteer = VolunteerProfileDto.fromJson(v).toEntity();
      }

      return success(
        MyProfile(profile: profile, requester: requester, volunteer: volunteer),
      );
    } catch (e) {
      return failure(mapSupabaseError(e));
    }
  }

  @override
  FutureResult<Unit> saveProfile({
    required UserRole role,
    required String fullName,
    Gender? gender,
    DateTime? dateOfBirth,
    String? phone,
    String? address,
    String? homeLocationText,
  }) async {
    try {
      await _client.rpc('upsert_my_profile', params: {
        'p_role': role.wireValue,
        'p_full_name': fullName,
        'p_gender': gender?.wireValue,
        'p_date_of_birth': dateOfBirth == null ? null : _dateOnly(dateOfBirth),
        'p_phone': phone,
        'p_address': address,
        'p_home_location_text': homeLocationText,
      });
      return success(unit);
    } catch (e) {
      return failure(mapSupabaseError(e));
    }
  }

  @override
  FutureResult<Unit> setAvailability(bool isActive) async {
    final uid = _uid;
    if (uid == null) {
      return failure(const AuthFailure('You are not signed in.'));
    }
    try {
      await _client
          .from('profiles')
          .update({'is_active': isActive}).eq('id', uid);
      return success(unit);
    } catch (e) {
      return failure(mapSupabaseError(e));
    }
  }

  /// Formats a [DateTime] as `YYYY-MM-DD` for a Postgres `date` column.
  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
