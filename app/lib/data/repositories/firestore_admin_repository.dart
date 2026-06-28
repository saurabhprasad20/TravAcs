import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/firebase_error_mapper.dart';
import '../../core/error/result.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/pending_volunteer.dart';
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
        .map((snap) => snap.docs.map(_toPending).toList());
  }

  @override
  FutureResult<Unit> setVerification(
      String uid, bool approved, String? reason) async {
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
}
