import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';

class CustomerRepository {
  final DioClient dio;
  CustomerRepository(this.dio);
  Map<String, dynamic> _data(Response response) {
    if ((response.statusCode ?? 500) >= 400 || response.data is! Map) {
      throw Exception(response.data is Map
          ? response.data['error'] ?? '客户资料请求失败'
          : '客户资料请求失败');
    }
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> list({String search = '', int page = 1}) async =>
      _data(await dio.get('/api/customers',
          queryParameters: {'search': search, 'page': page}));
  Future<Map<String, dynamic>> detail(String id) async =>
      _data(await dio.get('/api/customers/$id'));
  Future<Map<String, dynamic>> forConversation(String id) async =>
      _data(await dio.get('/api/customers/conversation/$id'));
  Future<void> update(String id, Map<String, dynamic> fields) async {
    _data(await dio.patch('/api/customers/$id', data: fields));
  }

  Future<String> createIntake(String id) async => _data(await dio
          .post('/api/customers/conversation/$id/intake-link', data: {}))['url']
      as String;
  Future<Map<String, dynamic>> statuses(List<String> ids) async =>
      _data(await dio.post('/api/customers/conversation-statuses',
          data: {'conversationIds': ids.take(200).toList()}));
  Future<Uint8List> exportPdf(String id, {bool includeNotes = false}) async =>
      download('/api/customers/$id/export.pdf?includeNotes=$includeNotes',
          pdf: true);
  Future<Uint8List> download(String path, {bool pdf = false}) async {
    if (!path.startsWith('/api/customers/')) throw Exception('文件地址无效');
    final response = await dio.get<List<int>>(path,
        options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(minutes: 3)));
    if (response.statusCode != 200 || response.data == null) {
      throw Exception('文件下载失败，请重试');
    }
    final bytes = Uint8List.fromList(response.data!);
    if (pdf &&
        (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-')) {
      throw Exception('PDF 导出失败');
    }
    return bytes;
  }
}

final customerRepositoryProvider =
    Provider((ref) => CustomerRepository(ref.watch(dioProvider)));
