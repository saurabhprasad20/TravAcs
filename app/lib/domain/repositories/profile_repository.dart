import 'package:fpdart/fpdart.dart';

import '../../core/error/result.dart';
import '../entities/enums.dart';
import '../entities/profile.dart';

/// Profile data access (design §7, §10). Profile mutations go through the
/// `upsert_my_profile` RPC so creation is atomic and role-safe.
abstract interface class ProfileRepository {
  /// Returns the signed-in user's [MyProfile], or `null` if they have
  /// authenticated but not yet completed registration.
  FutureResult<MyProfile?> getMyProfile();

  /// Creates or updates the caller's profile + role-specific row.
  FutureResult<Unit> saveProfile({
    required UserRole role,
    required String fullName,
    required Region region,
    Gender? gender,
    DateTime? dateOfBirth,
    String? phone,
    String? address,
    String? homeLocationText,
  });

  /// Updates the caller's service region (`profiles.serviceArea`).
  FutureResult<Unit> setRegion(Region region);

  /// Toggles a volunteer's availability (`profiles.is_active`).
  FutureResult<Unit> setAvailability(bool isActive);
}
