import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../models/user.dart';

class AuthRepository {
  final DioClient _dio;

  AuthRepository(this._dio);

  void setCookie(String cookie) {
    _dio.setCookie(cookie);
  }

  String? getCookie() => _dio.cookie;

  Future<AgentUser?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final userData = data['user'] ?? data;
          if (userData is Map<String, dynamic>) {
            return AgentUser.fromJson(userData);
          }
        }
      }

      final errorMsg = _extractErrorMessage(response.data);
      throw Exception(errorMsg ?? '邮箱或密码错误');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('登录失败：$e');
    }
  }

  Future<AgentUser?> getCurrentUser() async {
    try {
      final response = await _dio.get('/api/agent/settings');
      if (response.statusCode == 200 && response.data != null) {
        return AgentUser.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout', data: {});
    } catch (e) {
      // Ignore
    }
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['error'] as String? ?? data['message'] as String?;
    }
    if (data is String) return data;
    return null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});
