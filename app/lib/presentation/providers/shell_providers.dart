import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The requester "My Requests" tab index within the requester shell (see the
/// requester tab order in `app_shell.dart`). Submitting a request switches here.
const int requesterMyRequestsTabIndex = 1;

/// Holds the currently-selected bottom-tab index for [AppShell]. Lifting this
/// out of the shell's local state lets tab content (e.g. the New Request form)
/// drive navigation — after a successful submit we switch to My Requests.
class ShellTabIndex extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final shellTabIndexProvider =
    NotifierProvider<ShellTabIndex, int>(ShellTabIndex.new);
