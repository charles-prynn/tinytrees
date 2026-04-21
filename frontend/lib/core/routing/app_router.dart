import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_controller.dart';
import '../../features/shared/loading_screen.dart';
import '../../features/shared/main_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loading = auth.isLoading;
      final ready = auth.hasValue && auth.value != null;
      final onLoading = state.matchedLocation == '/loading';

      if (loading && !onLoading) return '/loading';
      if (!loading && !ready && !onLoading) return '/loading';
      if (!loading && ready && onLoading) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainScreen()),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
    ],
  );
});
