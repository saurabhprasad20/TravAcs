import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/city.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../providers/profile_providers.dart';

/// Handles profile creation/update and the volunteer availability toggle.
/// Invalidates [myProfileProvider] on success so the router and UI refresh.
class ProfileController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  Future<bool> save({
    required UserRole role,
    required String fullName,
    required Region serviceState,
    required City serviceCity,
    Gender? gender,
    DateTime? dateOfBirth,
    String? phone,
    String? address,
    String? homeLocationText,
  }) async {
    state = const AsyncLoading();
    final res = await _repo.saveProfile(
      role: role,
      fullName: fullName,
      state: serviceState,
      city: serviceCity,
      gender: gender,
      dateOfBirth: dateOfBirth,
      phone: phone,
      address: address,
      homeLocationText: homeLocationText,
    );
    return res.match(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(myProfileProvider);
        return true;
      },
    );
  }

  Future<bool> setServiceArea(Region serviceState, City serviceCity) async {
    state = const AsyncLoading();
    final res = await _repo.setServiceArea(serviceState, serviceCity);
    return res.match(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(myProfileProvider);
        return true;
      },
    );
  }

  Future<bool> setAvailability(bool isActive) async {
    state = const AsyncLoading();
    final res = await _repo.setAvailability(isActive);
    return res.match(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(myProfileProvider);
        return true;
      },
    );
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, AsyncValue<void>>(ProfileController.new);
