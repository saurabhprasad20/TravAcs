import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/firebase_error_mapper.dart';
import '../../core/error/result.dart';
import '../../core/error/stream_error.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/pending_volunteer.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/admin_repository.dart';

class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<PendingVolunteer>> watchPendingVolunteers() {
    return _db
        .collection('profiles')
        .where('role', isEqualTo: 'volunteer')
        .where('verificationStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(_toPending).toList())
        .mapErrorToFailure();
  }

  @override
  Stream<List<Profile>> watchAccounts() {
    return _db.collection('profiles').snapshots().map((snap) {
      final profiles =
          snap.docs
              .map((doc) => _toProfile(doc.id, doc.data()))
              .whereType<Profile>()
              .toList();
      profiles.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
      return profiles;
    }).mapErrorToFailure();
  }

  @override
  FutureResult<Unit> setVerification(
    String uid,
    bool approved,
    String? reason,
  ) async {
    try {
      await _functions.httpsCallable('setVerification').call<dynamic>({
        'uid': uid,
        'decision': approved ? 'approved' : 'rejected',
        'reason': reason,
      });
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  FutureResult<Unit> setAccountBan(
    String uid, {
    DateTime? bannedUntil,
    String? reason,
  }) async {
    try {
      await _functions.httpsCallable('setAccountBan').call<dynamic>({
        'uid': uid,
        'bannedUntilMs': bannedUntil?.millisecondsSinceEpoch,
        'reason': reason,
      });
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  FutureResult<Unit> setTravelCompensation(
    String requestId,
    String volunteerId,
    int travelCostInr,
  ) async {
    try {
      await _functions.httpsCallable('setTravelCompensation').call<dynamic>({
        'requestId': requestId,
        'volunteerId': volunteerId,
        'travelCostInr': travelCostInr,
      });
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  FutureResult<Unit> finalizePaymentReview(String requestId) async {
    try {
      await _functions.httpsCallable('finalizePaymentReview').call<dynamic>({
        'requestId': requestId,
      });
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  FutureResult<Unit> logManualTrip({
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
  }) async {
    try {
      await _functions.httpsCallable('logManualTrip').call<dynamic>({
        'userDetails': userDetails,
        'travAcserNames': travAcserNames,
        'tripDateMs': tripDate.millisecondsSinceEpoch,
        'startTime': startTime,
        'numTravellers': numTravellers,
        'numTravAcsers': numTravAcsers,
        'genderPreference': genderPreference.wireValue,
        'durationMinutes': durationMinutes,
        'meetingPoint': meetingPoint,
        'destination': destination,
        'estimatedAmountInr': estimatedAmountInr,
        'note': note,
      });
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  PendingVolunteer _toPending(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return PendingVolunteer(
      uid: doc.id,
      fullName: (d['fullName'] as String?) ?? '',
      phone: d['phone'] as String?,
      address: d['address'] as String?,
      state: Region.fromWireOrNull(d['serviceArea'] as String?),
      city: City.fromWire(d['serviceCity'] as String?),
      gender: Gender.fromWire(d['gender'] as String?),
      dateOfBirth: (d['dateOfBirth'] as Timestamp?)?.toDate(),
    );
  }

  Profile? _toProfile(String uid, Map<String, dynamic> d) {
    final roleValue = d['role'] as String?;
    if (roleValue != 'requester' && roleValue != 'volunteer') return null;
    return Profile(
      id: uid,
      role: UserRole.fromWire(roleValue!),
      fullName: (d['fullName'] as String?) ?? '',
      gender: Gender.fromWire(d['gender'] as String?),
      dateOfBirth: (d['dateOfBirth'] as Timestamp?)?.toDate(),
      phone: d['phone'] as String?,
      isActive: (d['isActive'] as bool?) ?? true,
      bannedUntil: (d['bannedUntil'] as Timestamp?)?.toDate(),
      banReason: d['banReason'] as String?,
      serviceArea: Region.fromWireOrNull(d['serviceArea'] as String?),
      serviceCity: City.fromWire(d['serviceCity'] as String?),
    );
  }
}
