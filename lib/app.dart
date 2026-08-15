import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/agent/pages/agent_home_page.dart';
import 'features/agent/pages/chat_page.dart';
import 'features/admin/pages/admin_home_page.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/providers/auth_providers.dart';
import 'shared/widgets/loading.dart';

class ConsultingOnlineApp extends ConsumerWidget {
  const ConsultingOnlineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return WithForegroundTask(
      child: MaterialApp.router(
        title: '在线客服',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  Future.microtask(() {
    ref.read(authProvider.notifier).checkAuth();
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/';

      if (authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading) {
        return isSplash ? null : '/';
      }

      if (isSplash) {
        if (isLoggedIn) {
          return '/agent';
        }
        return '/login';
      }

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/agent';
      }

      final isAdminPath = state.matchedLocation == '/admin';
      if (isLoggedIn && isAdminPath && !ref.read(isAdminProvider)) {
        return '/agent';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/agent',
        builder: (context, state) => const AgentHomePage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHomePage(),
      ),
      GoRoute(
        path: '/agent/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ChatPage(conversationId: id);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面不存在')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('页面不存在'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
});

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.headset_mic_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text('在线客服', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            const LoadingIndicator(size: 32),
          ],
        ),
      ),
    );
  }
}
