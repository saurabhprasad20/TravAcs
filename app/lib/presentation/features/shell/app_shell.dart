import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../menu/app_menu_drawer.dart';
import '../profile/profile_tab_screen.dart';
import '../requester/my_requests_screen.dart';
import '../requester/new_request_screen.dart';
import '../requester/trip_history_screen.dart' as req;
import '../volunteer/available_requests_screen.dart';
import '../volunteer/my_trips_screen.dart';
import '../volunteer/trip_history_screen.dart' as vol;
import '../../providers/messaging_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/shell_providers.dart';

/// WhatsApp/Instagram-style bottom-tab shell (design §10). A persistent
/// [NavigationBar] over an [IndexedStack] (preserves each tab's state). Tabs are
/// role-specific. Feature tabs are placeholders until M3–M6; Profile is live.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    // Register this device for push and react to token refresh / foreground
    // messages. Runs once the user is in the shell (authenticated + profiled).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messaging = ref.read(messagingRepositoryProvider);
      // Fire-and-forget: registerToken() is already fully guarded, but add a
      // safety catch so an un-awaited rejection can never become an uncaught
      // (fatal) error.
      unawaited(messaging.registerToken().catchError((_) {}));
      _subs.add(messaging.onTokenRefresh
          .listen(messaging.onRefresh, onError: (_) {}));
      _subs.add(messaging.onForegroundMessage.listen((m) {
        final text = m.notification?.body ?? m.notification?.title;
        if (text != null && mounted) {
          A11y.announce(context, text);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(text)));
        }
      }, onError: (_) {}));
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final my = ref.watch(myProfileProvider).value;
    if (my == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = my.profile.isVolunteer ? _volunteerTabs : _requesterTabs;
    // Guard against an out-of-range index if the role/tab set changes.
    final index = ref.watch(shellTabIndexProvider).clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(title: Text(tabs[index].title ?? tabs[index].label)),
      drawer: const AppMenuDrawer(),
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          // Dismiss the keyboard so it never lingers or auto-opens when
          // switching tabs (e.g. back to the Request form).
          FocusManager.instance.primaryFocus?.unfocus();
          ref.read(shellTabIndexProvider.notifier).set(i);
          // Confirm navigation for screen-reader users (the content swaps
          // silently otherwise).
          A11y.announce(context, '${tabs[i].label} tab');
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }

  // Requester tabs (design §10.2). Feature tabs are placeholders for now.
  static const _requesterTabs = <_TabDef>[
    _TabDef(
      label: 'Request',
      title: 'New Request',
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      screen: NewRequestScreen(),
    ),
    _TabDef(
      label: 'My Requests',
      icon: Icons.list_alt_outlined,
      selectedIcon: Icons.list_alt,
      screen: MyRequestsScreen(),
    ),
    _TabDef(
      label: 'History',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      screen: req.TripHistoryScreen(),
    ),
    _TabDef(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      screen: ProfileTabScreen(),
    ),
  ];

  // Volunteer tabs (design §10.3).
  static const _volunteerTabs = <_TabDef>[
    _TabDef(
      label: 'Available',
      title: 'Available Requests',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      screen: AvailableRequestsScreen(),
    ),
    _TabDef(
      label: 'My Trips',
      icon: Icons.directions_walk_outlined,
      selectedIcon: Icons.directions_walk,
      screen: MyTripsScreen(),
    ),
    _TabDef(
      label: 'History',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      screen: vol.TripHistoryScreen(),
    ),
    _TabDef(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      screen: ProfileTabScreen(),
    ),
  ];
}

class _TabDef {
  const _TabDef({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
    this.title,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;

  /// Optional AppBar title (defaults to [label]).
  final String? title;
}
