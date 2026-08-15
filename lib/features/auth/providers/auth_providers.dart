import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/notifications/foreground_service.dart';
import '../../../core/utils/storage.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final AgentUser? user;
  final String? error;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    AgentUser? user,
    String? error,
    bool? isLoading,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final StorageService _storage;
  final WsClient _wsClient;

  AuthNotifier(this._authRepository, this._storage, this._wsClient)
    : super(const AuthState());

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading, isLoading: true);

    try {
      final cookie = await _storage.getCookie();
      if (cookie != null) {
        _authRepository.setCookie(cookie);
        _wsClient.setCookie(cookie);
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          _wsClient.connect();
          ForegroundService.instance.start();
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            isLoading: false,
            clearError: true,
          );
          return;
        }
      }
      await _storage.removeCookie();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        clearUser: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        clearUser: true,
      );
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null, clearError: true);

    try {
      final user = await _authRepository.login(email, password);
      final cookie = _authRepository.getCookie();

      if (cookie != null) {
        await _storage.setCookie(cookie);
        _wsClient.setCookie(cookie);
      }

      _wsClient.connect();
      ForegroundService.instance.start();

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString().replaceFirst('Exception: ', ''),
        isLoading: false,
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } catch (e) {
      // Ignore logout errors
    }

    // 主动断开并清除 cookie，防止失效 cookie 触发重连死循环。
    _wsClient.setCookie(null);
    _wsClient.disconnect();
    try {
      await ForegroundService.instance.stop();
    } catch (e) {
      // 前台服务停止失败不影响退出。
    }
    try {
      await _storage.removeCookie();
    } catch (e) {
      // 清理本地 cookie 失败不影响退出。
    }

    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: false,
    );
  }

  void updateUser(AgentUser user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final storage = ref.watch(storageProvider);
  final wsClient = ref.watch(wsClientProvider);
  return AuthNotifier(authRepo, storage, wsClient);
});

final currentUserProvider = Provider<AgentUser?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isAdmin ?? false;
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final storage = ref.watch(storageProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final StorageService _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final saved = await _storage.getThemeMode();
    if (saved != null) {
      switch (saved) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        default:
          state = ThemeMode.system;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    switch (mode) {
      case ThemeMode.light:
        await _storage.setThemeMode('light');
        break;
      case ThemeMode.dark:
        await _storage.setThemeMode('dark');
        break;
      case ThemeMode.system:
        await _storage.setThemeMode('system');
    }
  }

  Future<void> toggleTheme() async {
    if (state == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}
