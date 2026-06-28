import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';
import '../../core/error/firebase_error_mapper.dart';
import '../../core/error/result.dart';
import '../../domain/entities/assignment.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/request.dart';
import '../../domain/repositories/request_repository.dart';

/// Firestore implementation of [RequestRepository].
class FirestoreRequestRepository implements RequestRepository {
  FirestoreRequestRepository(this._db, this._auth, this._functions);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('requests');

  String? get _uid => _auth.currentUser?.uid;

  @override
  FutureResult<String> createRequest({
    required Region serviceState,
    required City serviceCity,
    required String requesterName,
    required int numTravellers,
    required int numTravAcsers,
    required int numMaleTravellers,
    required int numFemaleTravellers,
    required DateTime scheduledDate,
    required String startTime,
    required int expectedDurationMinutes,
    required String meetingPoint,
    required String destination,
    String? landmark,
    String? purpose,
    String? specialNote,
  }) async {
    final uid = _uid;
    if (uid == null) return failure(const AuthFailure('You are not signed in.'));
    try {
      final doc = await _requests.add({
        'requesterId': uid,
        'requesterName': requesterName,
        'volunteerId': null,
        'status': RequestStatus.broadcast.wireValue,
        'serviceArea': serviceState.wireValue,
        'serviceCity': serviceCity.wireValue,
        'acceptedCount': 0,
        'numTravellers': numTravellers,
        'numTravAcsers': numTravAcsers,
        'numMaleTravellers': numMaleTravellers,
        'numFemaleTravellers': numFemaleTravellers,
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        'startTime': startTime,
        'expectedDurationMinutes': expectedDurationMinutes,
        'meetingPoint': meetingPoint,
        'destination': destination,
        'landmark': landmark,
        'purpose': purpose,
        'specialNote': specialNote,
        'estimatedAmountInr':
            Request.computeEstimate(expectedDurationMinutes, numTravAcsers),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return success(doc.id);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  Stream<List<Request>> watchMyRequests() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _requests
        .where('requesterId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  @override
  Stream<List<Request>> watchAvailableRequests(City city) {
    return _requests
        .where('status', isEqualTo: RequestStatus.broadcast.wireValue)
        .where('serviceCity', isEqualTo: city.wireValue)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  @override
  FutureResult<Unit> cancelRequest(String id) async {
    try {
      await _requests.doc(id).update({
        'status': RequestStatus.cancelled.wireValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  FutureResult<Unit> acceptRequest(String requestId) async {
    try {
      await _functions
          .httpsCallable('acceptRequest')
          .call<dynamic>({'requestId': requestId});
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  FutureResult<Unit> startTrip(String requestId, String otp) async {
    try {
      await _functions
          .httpsCallable('startTrip')
          .call<dynamic>({'requestId': requestId, 'otp': otp});
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  FutureResult<Unit> completeTrip(String requestId, String volunteerId) async {
    try {
      await _functions.httpsCallable('completeTrip').call<dynamic>(
          {'requestId': requestId, 'volunteerId': volunteerId});
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  FutureResult<Unit> markPaid(String requestId, String volunteerId) =>
      _call('markPaid', {'requestId': requestId, 'volunteerId': volunteerId});

  @override
  FutureResult<Unit> markReceived(String requestId) =>
      _call('markReceived', {'requestId': requestId});

  @override
  FutureResult<Unit> submitRating(
    String requestId,
    String volunteerId,
    int stars,
    String? feedback,
  ) =>
      _call('submitRating', {
        'requestId': requestId,
        'volunteerId': volunteerId,
        'stars': stars,
        'feedback': feedback,
      });

  /// Shared helper to invoke a callable and map errors.
  FutureResult<Unit> _call(String name, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(name).call<dynamic>(data);
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  Stream<List<Assignment>> watchMyAssignments() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collectionGroup('assignments')
        .where('volunteerId', isEqualTo: uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map(_toAssignment).whereType<Assignment>().toList());
  }

  @override
  Stream<List<Assignment>> watchRequestAssignments(String requestId) {
    return _requests
        .doc(requestId)
        .collection('assignments')
        .snapshots()
        .map((snap) =>
            snap.docs.map(_toAssignment).whereType<Assignment>().toList());
  }

  @override
  Stream<String?> watchShareOtp(String requestId, String volunteerId) {
    return _requests
        .doc(requestId)
        .collection('secrets')
        .doc(volunteerId)
        .snapshots()
        .map((doc) => doc.data()?['otp'] as String?);
  }

  // --- mapping ---------------------------------------------------------------

  Assignment? _toAssignment(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    // requestId = the assignment's grandparent doc (requests/{id}/assignments/{vid}).
    final requestId = doc.reference.parent.parent?.id;
    final scheduled = (d['scheduledDate'] as Timestamp?)?.toDate();
    if (requestId == null || scheduled == null) return null;
    return Assignment(
      requestId: requestId,
      volunteerId: (d['volunteerId'] as String?) ?? doc.id,
      volunteerName: (d['volunteerName'] as String?) ?? '',
      volunteerPhone: d['volunteerPhone'] as String?,
      requesterId: (d['requesterId'] as String?) ?? '',
      requesterName: (d['requesterName'] as String?) ?? '',
      requesterPhone: d['requesterPhone'] as String?,
      scheduledDate: scheduled,
      startTime: (d['startTime'] as String?) ?? '',
      expectedDurationMinutes: (d['expectedDurationMinutes'] as num?)?.toInt() ?? 60,
      meetingPoint: (d['meetingPoint'] as String?) ?? '',
      destination: (d['destination'] as String?) ?? '',
      landmark: d['landmark'] as String?,
      numTravellers: (d['numTravellers'] as num?)?.toInt() ?? 1,
      amountInrEstimate: (d['amountInrEstimate'] as num?)?.toInt() ?? 0,
      tripStatus: TripStatus.fromWire(d['tripStatus'] as String?),
      acceptedAt: (d['acceptedAt'] as Timestamp?)?.toDate(),
      startedAt: (d['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (d['endedAt'] as Timestamp?)?.toDate(),
      durationMinutes: (d['durationMinutes'] as num?)?.toInt(),
      amountInr: (d['amountInr'] as num?)?.toInt(),
      paymentStatus: PaymentStatus.fromWire(d['paymentStatus'] as String?),
      requesterPaidAt: (d['requesterPaidAt'] as Timestamp?)?.toDate(),
      travAcserReceivedAt: (d['travAcserReceivedAt'] as Timestamp?)?.toDate(),
      requesterRatingStars: (d['requesterRatingStars'] as num?)?.toInt(),
      requesterRatingFeedback: d['requesterRatingFeedback'] as String?,
      volunteerRatingStars: (d['volunteerRatingStars'] as num?)?.toInt(),
      volunteerRatingFeedback: d['volunteerRatingFeedback'] as String?,
    );
  }

  List<Request> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map(_toRequest).whereType<Request>().toList(growable: false);

  Request? _toRequest(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final city = City.fromWire(d['serviceCity'] as String?);
    final state = Region.fromWireOrNull(d['serviceArea'] as String?);
    final scheduled = (d['scheduledDate'] as Timestamp?)?.toDate();
    if (city == null || state == null || scheduled == null) return null;
    return Request(
      id: doc.id,
      requesterId: (d['requesterId'] as String?) ?? '',
      volunteerId: d['volunteerId'] as String?,
      status: RequestStatus.fromWire((d['status'] as String?) ?? 'broadcast'),
      serviceState: state,
      serviceCity: city,
      numTravellers: (d['numTravellers'] as num?)?.toInt() ?? 1,
      numTravAcsers: (d['numTravAcsers'] as num?)?.toInt() ?? 1,
      acceptedCount: (d['acceptedCount'] as num?)?.toInt() ?? 0,
      numMaleTravellers: (d['numMaleTravellers'] as num?)?.toInt() ?? 0,
      numFemaleTravellers: (d['numFemaleTravellers'] as num?)?.toInt() ?? 0,
      scheduledDate: scheduled,
      startTime: (d['startTime'] as String?) ?? '',
      expectedDurationMinutes:
          (d['expectedDurationMinutes'] as num?)?.toInt() ?? 60,
      meetingPoint: (d['meetingPoint'] as String?) ?? '',
      destination: (d['destination'] as String?) ?? '',
      landmark: d['landmark'] as String?,
      purpose: d['purpose'] as String?,
      specialNote: d['specialNote'] as String?,
      estimatedAmountInr: (d['estimatedAmountInr'] as num?)?.toInt() ?? 0,
      requesterName: d['requesterName'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
