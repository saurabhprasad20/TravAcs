import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';
import '../../core/error/firebase_error_mapper.dart';
import '../../core/error/result.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/request.dart';
import '../../domain/repositories/request_repository.dart';

/// Firestore implementation of [RequestRepository].
class FirestoreRequestRepository implements RequestRepository {
  FirestoreRequestRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

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

  // --- mapping ---------------------------------------------------------------

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
