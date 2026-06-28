import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether `Firebase.initializeApp` succeeded. Overridden in main(); if false,
/// the app shows the "Firebase not configured" screen (run `flutterfire
/// configure`).
final firebaseReadyProvider = Provider<bool>((ref) => false);

/// The shared [FirebaseAuth] instance (overridable in tests).
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// The shared [FirebaseFirestore] instance (overridable in tests).
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
