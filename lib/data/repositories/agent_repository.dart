import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/transfer_candidate.dart';
import '../models/user.dart';

class AgentRepository {
  final DioClient _dio;

  AgentRepository(this._dio);

  Future<AgentUser> getSettings() async {
    try {
      final response = await _dio.get('/api/agent/settings');
      if (response.statusCode == 200 && response.data != null) {
        return AgentUser.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('获取设置失败');
    } catch (e) {
      throw Exception('获取设置失败: $e');
    }
  }

  Future<AgentUser> updateSettings(Map<String, dynamic> updates) async {
    try {
      final response = await _dio.patch('/api/agent/settings', data: updates);
      if (response.statusCode == 200 && response.data != null) {
        return AgentUser.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('更新设置失败');
    } catch (e) {
      throw Exception('更新设置失败: $e');
    }
  }

  Future<List<Conversation>> getConversations({String? status}) async {
    try {
      final response = await _dio.get(
        '/api/agent/conversations',
        queryParameters: status != null && status != 'all'
            ? {'status': _mapStatus(status)}
            : null,
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list
            .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  String _mapStatus(String status) {
    switch (status) {
      case 'active':
        return 'OPEN';
      case 'browsing':
        return 'PENDING';
      case 'closed':
        return 'RESOLVED';
      default:
        return status;
    }
  }

  Future<Conversation> acceptConversation(String id) async {
    return updateConversation(id, {'status': 'OPEN'});
  }

  Future<bool> endConversation(String id) async {
    try {
      await updateConversation(id, {'status': 'RESOLVED'});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> transferConversation(String id, String agentId) async {
    try {
      await updateConversation(id, {'assigneeId': agentId});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Conversation> updateConversation(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dio.patch(
        '/api/agent/conversations/$id',
        data: updates,
      );
      if (response.statusCode == 200 && response.data != null) {
        return Conversation.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('更新会话失败');
    } catch (e) {
      throw Exception('更新会话失败: $e');
    }
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    String? before,
  }) async {
    try {
      final response = await _dio.get(
        '/api/agent/conversations/$conversationId/messages',
        queryParameters: before != null ? {'before': before} : null,
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        final messages = list
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        return messages.reversed.toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<HistoryItem>> getHistory(String conversationId) async {
    try {
      final response = await _dio.get(
        '/api/agent/conversations/$conversationId/history',
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<TransferCandidate>> getTransferCandidates(
    String conversationId,
  ) async {
    try {
      final response = await _dio.get(
        '/api/agent/transfer-candidates',
        queryParameters: {'conversationId': conversationId},
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list
            .map((e) => TransferCandidate.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<String?> translate(String conversationId, String body) async {
    try {
      final response = await _dio.post(
        '/api/agent/translate',
        data: {'conversationId': conversationId, 'body': body},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['translatedText'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadFile(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(
        '/api/agent/uploads',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['url'] as String? ?? data['pathname'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AgentRepository(dio);
});
