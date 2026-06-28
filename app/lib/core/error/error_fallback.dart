import 'package:flutter/material.dart';

/// Calm fallback shown instead of Flutter's default red/grey error box when a
/// widget fails to build in release. Self-contained (no inherited widgets) so it
/// works even at the top of the tree.
class ErrorFallback extends StatelessWidget {
  const ErrorFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFFFFFFF),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong.\nPlease go back or restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
            ),
          ),
        ),
      ),
    );
  }
}
