import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';
import '../../core/error/firebase_error_mapper.dart';
import '../../core/error/result.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// Firestore implementation of [ProfileRepository] (design §5). The user's
/// profile is a single document `profiles/{uid}` holding both base and
/// role-specific fields (one read). Protected fields (role, verificationStatus,
/// ratings) are write-restricted by Security Rules.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _db.collection('profiles');

  String? get _uid => _auth.currentUser?.uid;

  @override
  FutureResult<MyProfile?> getMyProfile() async {
    final uid = _uid;
    if (uid == null) return failure(const AuthFailure('You are not signed in.'));
    try {
      final doc = await _profiles.doc(uid).get();
      if (!doc.exists) return success(null); // not yet registered
      return success(_toMyProfile(uid, doc.data()!));
    } catch (e) {
      return failure(mapFirebaseError(e));
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
    final uid = _uid;
    if (uid == null) return failure(const AuthFailure('You are not signed in.'));
    try {
      final ref = _profiles.doc(uid);
      final existing = await ref.get();

      // Editable fields (allowed on both create and update by the rules).
      final data = <String, dynamic>{
        'fullName': fullName,
        'gender': gender?.wireValue,
        'dateOfBirth':
            dateOfBirth == null ? null : Timestamp.fromDate(dateOfBirth),
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
        if (role == UserRole.volunteer) 'address': address,
        if (role == UserRole.requester) 'homeLocationText': homeLocationText,
      };

      if (!existing.exists) {
        // First-time creation: set immutable/server-managed fields once.
        data.addAll({
          'role': role.wireValue,
          'isActive': true,
          'ratingAvg': 0,
          'ratingCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          if (role == UserRole.volunteer)
            'verificationStatus': VerificationStatus.pending.wireValue,
        });
      }

      await ref.set(data, SetOptions(merge: true));
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  @override
  FutureResult<Unit> setAvailability(bool isActive) async {
    final uid = _uid;
    if (uid == null) return failure(const AuthFailure('You are not signed in.'));
    try {
      await _profiles.doc(uid).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return success(unit);
    } catch (e) {
      return failure(mapFirebaseError(e));
    }
  }

  // --- mapping ---------------------------------------------------------------

  MyProfile _toMyProfile(String uid, Map<String, dynamic> d) {
    final role = UserRole.fromWire(d['role'] as String);
    final profile = Profile(
      id: uid,
      role: role,
      fullName: (d['fullName'] as String?) ?? '',
      gender: Gender.fromWire(d['gender'] as String?),
      dateOfBirth: (d['dateOfBirth'] as Timestamp?)?.toDate(),
      phone: d['phone'] as String?,
      isActive: (d['isActive'] as bool?) ?? true,
    );

    RequesterProfile? requester;
    VolunteerProfile? volunteer;
    if (role == UserRole.requester) {
      requester = RequesterProfile(
        profileId: uid,
        homeLocationText: d['homeLocationText'] as String?,
        ratingAvg: _toDouble(d['ratingAvg']),
        ratingCount: (d['ratingCount'] as num?)?.toInt() ?? 0,
      );
    } else if (role == UserRole.volunteer) {
      volunteer = VolunteerProfile(
        profileId: uid,
        address: d['address'] as String?,
        verificationStatus:
            VerificationStatus.fromWire((d['verificationStatus'] as String?) ?? 'pending'),
        rejectionReason: d['rejectionReason'] as String?,
        ratingAvg: _toDouble(d['ratingAvg']),
        ratingCount: (d['ratingCount'] as num?)?.toInt() ?? 0,
      );
    }
    return MyProfile(profile: profile, requester: requester, volunteer: volunteer);
  }

  static double _toDouble(Object? v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
}
