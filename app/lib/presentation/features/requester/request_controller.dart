import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/city.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/razorpay_order.dart';
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

  /// TravAcser continues (accept=true) or cancels (accept=false) a rescheduled
  /// trip.
  Future<bool> respondReschedule(String requestId, bool accept) =>
      _run(() => _repo.respondReschedule(requestId, accept));

  /// End/complete a TravAcser's trip (either party).
  Future<bool> completeTrip(String requestId, String volunteerId) =>
      _run(() => _repo.completeTrip(requestId, volunteerId));

  /// Start a trip once the TravAcser has validated the User's start code
  /// (offline, deterministic). Called by the TravAcser.
  Future<bool> startTrip(String requestId, String volunteerId) =>
      _run(() => _repo.startTrip(requestId, volunteerId));

  /// User marks a TravAcser's payment as Paid.
  Future<bool> markPaid(String requestId, String volunteerId) =>
      _run(() => _repo.markPaid(requestId, volunteerId));

  /// Creates a Razorpay order for a completed assignment. Returns the order
  /// (with key id) on success, or null on failure (error in state).
  Future<RazorpayOrder?> createRazorpayOrder(
      String requestId, String volunteerId) async {
    state = const AsyncLoading();
    final res = await _repo.createRazorpayOrder(requestId, volunteerId);
    return res.match(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return null;
      },
      (order) {
        state = const AsyncData(null);
        return order;
      },
    );
  }

  /// Verifies a Razorpay payment server-side and marks the trip paid.
  Future<bool> verifyRazorpayPayment({
    required String requestId,
    required String volunteerId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) =>
      _run(() => _repo.verifyRazorpayPayment(
            requestId: requestId,
            volunteerId: volunteerId,
            razorpayOrderId: razorpayOrderId,
            razorpayPaymentId: razorpayPaymentId,
            razorpaySignature: razorpaySignature,
          ));

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
