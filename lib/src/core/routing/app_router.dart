import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth_and_family/domain/app_user.dart';
import '../../features/auth_and_family/presentation/auth_family_providers.dart';
import '../../features/auth_and_family/presentation/onboarding_and_role_screen.dart';
import '../../features/dashboard_and_notifications/presentation/child_dashboard_screen.dart';
import '../../features/dashboard_and_notifications/presentation/parent_dashboard_screen.dart';

/// Role-aware declarative router integrated with Riverpod auth & household state
/// (Feature 1.1 & Section 2 of AGENTS.md).
final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(routerNotifier.dispose);

  return GoRouter(
    initialLocation: '/parent',
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider).asData?.value;
      final isSetupRoute = state.matchedLocation == '/setup';

      if (user == null || !user.isPairedToHousehold) {
        return isSetupRoute ? null : '/setup';
      }

      if (user.role == AccountRole.parent) {
        return state.matchedLocation == '/parent' ? null : '/parent';
      }

      if (user.role == AccountRole.child) {
        return state.matchedLocation == '/child' ? null : '/child';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) => const OnboardingAndRoleScreen(),
      ),
      GoRoute(
        path: '/parent',
        builder: (context, state) => const ParentDashboardScreen(),
      ),
      GoRoute(
        path: '/child',
        builder: (context, state) => const ChildDashboardScreen(),
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    _sub = ref.listen<AsyncValue<AppUser?>>(
      currentUserProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AppUser?>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

