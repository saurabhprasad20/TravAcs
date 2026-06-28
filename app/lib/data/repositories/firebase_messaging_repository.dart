import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM client: requests permission, registers the device token under
/// `devices/{uid}/tokens/{token}` (design §8), and cleans up on sign-out.
/// Sending is done server-side by the `onRequestCreated` Cloud Function.
class FirebaseMessagingRepository {
  FirebaseMessagingRepository(this._messaging, this._db, this._auth);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Requests notification permission and stores the current token for the
  /// signed-in user. Safe to call repeatedly.
  Future<void> registerToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null) await _writeToken(uid, token);
  }

  Future<void> onRefresh(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _writeToken(uid, token);
  }

  /// Removes this device's token (call before sign-out).
  Future<void> unregisterToken() async {
    final uid = _auth.currentUser?.uid;
    final token = await _messaging.getToken();
    if (uid != null && token != null) {
      await _tokenDoc(uid, token).delete().catchError((_) {});
    }
    await _messaging.deleteToken().catchError((_) {});
  }

  Future<void> _writeToken(String uid, String token) =>
      _tokenDoc(uid, token).set({
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  DocumentReference<Map<String, dynamic>> _tokenDoc(String uid, String token) =>
      _db.collection('devices').doc(uid).collection('tokens').doc(token);
}
