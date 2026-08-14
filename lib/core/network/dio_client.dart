import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

class DioClient {
  final Dio _dio;
  String? _cookie;

  DioClient() : _dio = Dio() {
    _dio.options
      ..baseUrl = AppConstants.apiBaseUrl
      ..connectTimeout = const Duration(milliseconds: AppConstants.connectTimeout)
      ..receiveTimeout = const Duration(milliseconds: AppConstants.receiveTimeout)
      ..headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }
      ..validateStatus = (status) => status != null && status < 500;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_cookie != null) {
            options.headers['Cookie'] = _cookie;
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _extractCookie(response);
          return handler.next(response);
        },
        onError: (error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  void _extractCookie(Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      final cookies = setCookie.map((c) {
        if (c.contains(';')) {
          return c.substring(0, c.indexOf(';'));
        }
        return c;
      }).toList();
      _cookie = cookies.join('; ');
    }
  }

  void setCookie(String? cookie) {
    _cookie = cookie;
  }

  String? get cookie => _cookie;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

final dioProvider = Provider<DioClient>((ref) {
  return DioClient();
});
