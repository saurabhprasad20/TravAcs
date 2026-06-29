import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/city.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/request_repository.dart';
import '../../providers/request_providers.dart';

/// Drives request creation + cancellation. Lists update live via streams, so no
/// explicit invalidation is needed.
class RequestController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  RequestRepository get _repo => ref.read(requestRepositoryProvider);

  /// Returns the new request id on success, or null on failure (error in state).
  Future<String?> create({
    required Region serviceState,
    required City serviceCity,
    required String requesterName,
    required int numTravellers,
    required int numTravAcsers,
    required GenderPreference genderPreference,
    required DateTime scheduledDate,
    required String startTime,
    required int expectedDurationMinutes,
    required String meetingPoint,
    required String destination,
    String? purpose,
    String? specialNote,
  }) async {
    state = const AsyncLoading();
    final res = await _repo.createRequest(
      serviceState: serviceState,
      serviceCity: serviceCity,
      requesterName: requesterName,
      numTravellers: numTravellers,
      numTravAcsers: numTravAcsers,
      genderPreference: genderPreference,
      scheduledDate: scheduledDate,
      startTime: startTime,
      expectedDurationMinutes: expectedDurationMinutes,
      meetingPoint: meetingPoint,
      destination: destination,
      purpose: purpose,
      specialNote: specialNote,
    );
    return res.match(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return null;
      },
      (id) {
        state = const AsyncData(null);
        return id;
      },
    );
  }

  Future<bool> cancel(String id) async {
    state = const AsyncLoading();
    final res = await _repo.cancelRequest(id);
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

  /// TravAcser claims a slot. Returns true on success.
  Future<bool> accept(String requestId) =>
      _run(() => _repo.acceptRequest(requestId));

  /// User reschedules a trip (new date + time) before it starts.
  Future<bool> reschedule(
          String requestId, DateTime scheduledDate, String startTime) =>
      _run(() => _repo.rescheduleTrip(requestId, scheduledDate, startTime));

  /// Cancel after acceptance — the server infers the caller's role (requester
  /// cancels the whole request; TravAcser releases their slot).
  Future<bool> cancelTrip(String requestId) =>
      _run(() => _repo.cancelTrip(requestId));

  /// End/complete a TravAcser's trip (either party).
  Future<bool> completeTrip(String requestId, String volunteerId) =>
      _run(() => _repo.completeTrip(requestId, volunteerId));

  /// User marks a TravAcser's payment as Paid.
  Future<bool> markPaid(String requestId, String volunteerId) =>
      _run(() => _repo.markPaid(requestId, volunteerId));

  /// TravAcser marks payment Received.
  Future<bool> markReceived(String requestId) =>
      _run(() => _repo.markReceived(requestId));

  /// Submit a rating for the counterpart.
  Future<bool> submitRating(
          String requestId, String volunteerId, int stars, String? feedback) =>
      _run(() => _repo.submitRating(requestId, volunteerId, stars, feedback));

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

final requestControllerProvider =
    NotifierProvider<RequestController, AsyncValue<void>>(RequestController.new);
