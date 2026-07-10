import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/error/firebase_error_mapper.dart';

/// FCM client: requests permission, registers the device token under
/// `devices/{uid}/tokens/{token}` (design §8), and cleans up on sign-out.
/// Sending is done server-side by the `onRequestCreated` Cloud Function.
///
/// Push is a best-effort convenience: every FCM/Firestore call here is guarded
/// so a transient failure (e.g. `SERVICE_NOT_AVAILABLE` from `getToken()` on a
/// flaky network / old Play Services) is logged as a non-fatal and swallowed —
/// it must never surface as an uncaught (fatal) crash or block the app.
class FirebaseMessagingRepository {
  FirebaseMessagingRepository(this._messaging, this._db, this._auth,
      {Duration retryBaseDelay = const Duration(seconds: 2)})
      : _retryBaseDelay = retryBaseDelay;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Duration _retryBaseDelay;

  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Requests notification permission and stores the current token for the
  /// signed-in user. Safe to call repeatedly; never throws.
  Future<void> registerToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _messaging.requestPermission();
      final token = await _getTokenWithRetry();
      if (token != null) await _writeToken(uid, token);
    } catch (e, stack) {
      // Log as a non-fatal (mapFirebaseError records it) and carry on — push is
      // optional and this commonly fails transiently on FCM's side.
      mapFirebaseError(e, stack);
    }
  }

  /// Fetches the FCM token, retrying a few times with exponential backoff since
  /// `SERVICE_NOT_AVAILABLE` is typically transient. Returns null if it keeps
  /// failing (caught upstream / here).
  Future<String?> _getTokenWithRetry({int attempts = 3}) async {
    for (var i = 0; i < attempts; i++) {
      try {
        return await _messaging.getToken();
      } catch (e, stack) {
        if (i == attempts - 1) {
          mapFirebaseError(e, stack);
          return null;
        }
        await Future<void>.delayed(_retryBaseDelay * (i + 1));
      }
    }
    return null;
  }

  Future<void> onRefresh(String token) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) await _writeToken(uid, token);
    } catch (e, stack) {
      mapFirebaseError(e, stack);
    }
  }

  /// Removes this device's token (call before sign-out). Never throws.
  Future<void> unregisterToken() async {
    try {
      final uid = _auth.currentUser?.uid;
      final token = await _getTokenWithRetry(attempts: 1);
      if (uid != null && token != null) {
        await _tokenDoc(uid, token).delete().catchError((_) {});
      }
      await _messaging.deleteToken().catchError((_) {});
    } catch (e, stack) {
      mapFirebaseError(e, stack);
    }
  }

  Future<void> _writeToken(String uid, String token) =>
      _tokenDoc(uid, token).set({
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  DocumentReference<Map<String, dynamic>> _tokenDoc(String uid, String token) =>
      _db.collection('devices').doc(uid).collection('tokens').doc(token);
}
