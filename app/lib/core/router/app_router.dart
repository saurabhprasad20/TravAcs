import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/features/admin/admin_screen.dart';
import '../../presentation/features/auth/otp_entry_screen.dart';
import '../../presentation/features/auth/phone_entry_screen.dart';
import '../../presentation/features/profile/complete_profile_screen.dart';
import '../../presentation/features/profile/account_suspended_screen.dart';
import '../../presentation/features/shell/app_shell.dart';
import '../../presentation/features/startup/splash_screen.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/profile_providers.dart';

/// Auth-aware router (design §7). Redirect rules:
///   • not authenticated            -> /auth/phone
///   • authenticated, profile loading -> /splash
///   • authenticated, no profile      -> /complete-profile
///   • authenticated, has profile     -> /home (role shell)
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder:
            (context, state) =>
                OtpEntryScreen(phone: state.uri.queryParameters['phone'] ?? ''),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/account-suspended',
        builder: (context, state) => const AccountSuspendedScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const AppShell()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
    ],
  );
});

/// Bridges Riverpod auth/profile state to go_router's [Listenable]-based
/// refresh, and computes redirects.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateChangesProvider, (_, __) => _stateChanged());
    _ref.listen(isAdminProvider, (_, __) => _stateChanged());
    _ref.listen(myProfileProvider, (_, __) => _stateChanged());
    _ref.listen(myAccountBanProvider, (_, __) => _stateChanged());
  }

  final Ref _ref;
  Timer? _banExpiryTimer;

  void _stateChanged() {
    _banExpiryTimer?.cancel();
    final liveUntil = _ref.read(myAccountBanProvider).value?.bannedUntil;
    final profileUntil =
        _ref.read(myProfileProvider).value?.profile.bannedUntil;
    final until = liveUntil ?? profileUntil;
    if (until != null && until.isAfter(DateTime.now())) {
      _banExpiryTimer = Timer(
        until.difference(DateTime.now()) + const Duration(milliseconds: 100),
        notifyListeners,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _banExpiryTimer?.cancel();
    super.dispose();
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final signedIn = _ref.read(authRepositoryProvider).currentUserId != null;
    final loc = state.matchedLocation;
    final inAuth = loc.startsWith('/auth');

    if (!signedIn) {
      return inAuth ? null : '/auth/phone';
    }

    // Admins go straight to the Admin screen (no requester/volunteer profile).
    return _ref
        .read(isAdminProvider)
        .when(
          loading: () => loc == '/splash' ? null : '/splash',
          error: (_, __) => _profileRedirect(loc, inAuth),
          data:
              (isAdmin) =>
                  isAdmin
                      ? (loc == '/admin' ? null : '/admin')
                      : _profileRedirect(loc, inAuth),
        );
  }

  /// Routing for normal (non-admin) users based on whether a profile exists.
  String? _profileRedirect(String loc, bool inAuth) {
    final liveBan = _ref.read(myAccountBanProvider);
    if (liveBan.value?.isActive == true) {
      return loc == '/account-suspended' ? null : '/account-suspended';
    }
    return _ref
        .read(myProfileProvider)
        .when(
          loading: () => loc == '/splash' ? null : '/splash',
          error: (_, __) => loc == '/splash' ? null : '/splash',
          data: (profile) {
            if (profile == null) {
              return loc == '/complete-profile' ? null : '/complete-profile';
            }
            if (profile.profile.isBanned) {
              return loc == '/account-suspended' ? null : '/account-suspended';
            }
            if (inAuth ||
                loc == '/splash' ||
                loc == '/complete-profile' ||
                loc == '/account-suspended' ||
                loc == '/admin') {
              return '/home';
            }
            return null;
          },
        );
  }
}
