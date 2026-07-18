import 'package:flutter/material.dart';

import '../../../core/accessibility/announce.dart';

/// Shows an accessible 1–5★ + optional feedback sheet. Returns `(stars, feedback)`
/// or null if dismissed.
Future<(int, String?)?> showRatingSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<(int, String?)>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _RatingSheet(title: title),
  );
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.title});
  final String title;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _stars = 0;
  final _feedback = TextEditingController();

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  Semantics(
                    button: true,
                    label: '$i star${i == 1 ? '' : 's'}',
                    selected: _stars == i,
                    child: IconButton(
                      iconSize: 40,
                      icon: Icon(i <= _stars ? Icons.star : Icons.star_border),
                      color: Colors.amber[700],
                      onPressed: () {
                        setState(() => _stars = i);
                        A11y.announce(
                            context, '$i star${i == 1 ? '' : 's'} selected');
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _feedback,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Feedback (optional)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _stars == 0
                  ? null
                  : () => Navigator.pop(
                        context,
                        (
                          _stars,
                          _feedback.text.trim().isEmpty
                              ? null
                              : _feedback.text.trim()
                        ),
                      ),
              child: const Text('Submit rating'),
            ),
          ],
        ),
      ),
    );
  }
}
