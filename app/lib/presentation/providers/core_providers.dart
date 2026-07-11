import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether `Firebase.initializeApp` succeeded. Overridden in main(); if false,
/// the app shows the "Firebase not configured" screen (run `flutterfire
/// configure`).
final firebaseReadyProvider = Provider<bool>((ref) => false);

/// Emits the current time on a fixed cadence so time-driven UI (e.g. "Ready to
/// start", the 30-minute availability cutoff) refreshes even when no Firestore
/// event arrives to trigger a rebuild. Widgets/providers that branch on the
/// wall clock should `ref.watch(clockProvider)`.
final clockProvider = StreamProvider<DateTime>((ref) {
  return Stream<DateTime>.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now(),
  );
});

/// The shared [FirebaseAuth] instance (overridable in tests).
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// The shared [FirebaseFirestore] instance (overridable in tests).
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
