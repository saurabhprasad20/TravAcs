import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_tab_screen.dart';
import '../../providers/profile_providers.dart';
import 'placeholder_tab.dart';

/// WhatsApp/Instagram-style bottom-tab shell (design §10). A persistent
/// [NavigationBar] over an [IndexedStack] (preserves each tab's state). Tabs are
/// role-specific. Feature tabs are placeholders until M3–M6; Profile is live.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final my = ref.watch(myProfileProvider).value;
    if (my == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = my.profile.isVolunteer ? _volunteerTabs : _requesterTabs;
    // Guard against an out-of-range index if the role/tab set changes.
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      screen: PlaceholderTab(
        title: 'New Request',
        icon: Icons.add_location_alt_outlined,
        note: 'Create assistance requests — coming in the next milestone',
      ),
    ),
    _TabDef(
      label: 'My Requests',
      icon: Icons.list_alt_outlined,
      selectedIcon: Icons.list_alt,
      screen: PlaceholderTab(
        title: 'My Requests',
        icon: Icons.list_alt_outlined,
      ),
    ),
    _TabDef(
      label: 'History',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      screen: PlaceholderTab(title: 'Trip History', icon: Icons.history),
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
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      screen: PlaceholderTab(
        title: 'Available Requests',
        icon: Icons.explore_outlined,
        note: 'Browse and accept requests — coming in the next milestone',
      ),
    ),
    _TabDef(
      label: 'My Trips',
      icon: Icons.directions_walk_outlined,
      selectedIcon: Icons.directions_walk,
      screen: PlaceholderTab(
        title: 'My Trips',
        icon: Icons.directions_walk_outlined,
      ),
    ),
    _TabDef(
      label: 'Earnings',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      screen: PlaceholderTab(title: 'Earnings', icon: Icons.payments_outlined),
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
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}
