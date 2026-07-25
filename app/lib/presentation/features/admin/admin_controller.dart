import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/admin_repository.dart';
import '../../providers/admin_providers.dart';

/// Drives admin approve/reject actions.
class AdminController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<bool> approve(String uid) =>
      _run(() => _repo.setVerification(uid, true, null));

  Future<bool> reject(String uid, String? reason) =>
      _run(() => _repo.setVerification(uid, false, reason));

  /// Log a manually-booked (phone) trip into the telemetry collection. Mirrors
  /// the trip request form plus a free-text list of TravAcser names (item 12).
  Future<bool> logManualTrip({
    required String userDetails,
    required String travAcserNames,
    required DateTime tripDate,
    required String startTime,
    required int numTravellers,
    required int numTravAcsers,
    required GenderPreference genderPreference,
    required int durationMinutes,
    required String meetingPoint,
    required String destination,
    required int estimatedAmountInr,
    String? note,
  }) =>
      _run(() => _repo.logManualTrip(
            userDetails: userDetails,
            travAcserNames: travAcserNames,
            tripDate: tripDate,
            startTime: startTime,
            numTravellers: numTravellers,
            numTravAcsers: numTravAcsers,
            genderPreference: genderPreference,
            durationMinutes: durationMinutes,
            meetingPoint: meetingPoint,
            destination: destination,
            estimatedAmountInr: estimatedAmountInr,
            note: note,
          ));

  Future<bool> _run(FutureResult<Unit> Function() action) async {
    state = const AsyncLoading();
    final res = await action();
    return res.match(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

final adminControllerProvider =
    NotifierProvider<AdminController, AsyncValue<void>>(AdminController.new);
