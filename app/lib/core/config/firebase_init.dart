import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Initializes Firebase. Call once during startup before `runApp`. Throws if
/// `firebase_options.dart` is still the placeholder (i.e. `flutterfire
/// configure` hasn't been run) — main() catches that and shows a clear screen.
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
