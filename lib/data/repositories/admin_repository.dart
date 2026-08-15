import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../models/conversation.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../models/site.dart';

/// Maps the `AssignmentRule` enum to the string value the backend expects.
String assignmentRuleToApi(AssignmentRule rule) {
  switch (rule) {
    case AssignmentRule.sequential:
      return 'SEQUENTIAL';
    case AssignmentRule.conversionRate:
      return 'CONVERSION_RATE';
    case AssignmentRule.average:
      return 'AVERAGE';
  }
}

class AdminConversationDetail {
  final Conversation conversation;
  final List<ChatMessage> messages;

  const AdminConversationDetail({
    required this.conversation,
    required this.messages,
  });
}

class AdminRepository {
  final DioClient _dio;

  AdminRepository(this._dio);

  Future<DashboardStats> getDashboard() async {
    final response = await _dio.get('/api/admin/dashboard');
    if (response.statusCode == 200 && response.data != null) {
      return DashboardStats.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception(_errorMessage(response.data, '获取仪表盘数据失败'));
  }

  Future<List<AdminUser>> getUsers() async {
    final response = await _dio.get('/api/admin/users');
    if (response.statusCode == 200 && response.data != null) {
      final list = response.data as List<dynamic>;
      return list
          .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_errorMessage(response.data, '获取账号列表失败'));
  }

  Future<AdminUser> createUser(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/admin/users', data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return AdminUser.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception(_errorMessage(response.data, '创建账号失败'));
  }

  Future<List<AgentGroup>> getGroups() async {
    final response = await _dio.get('/api/admin/groups');
    if (response.statusCode == 200 && response.data != null) {
      final list = response.data as List<dynamic>;
      return list
          .map((e) => AgentGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_errorMessage(response.data, '获取分组列表失败'));
  }

  Future<AgentGroup> createGroup(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/admin/groups', data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return AgentGroup.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception(_errorMessage(response.data, '创建分组失败'));
  }

  Future<AgentGroup> updateGroup(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/api/admin/groups/$id', data: data);
    if (response.statusCode == 200) {
      return AgentGroup.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception(_errorMessage(response.data, '更新分组失败'));
  }

  Future<void> deleteGroup(String id) async {
    final response = await _dio.delete('/api/admin/groups/$id');
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.data, '删除分组失败'));
    }
  }

  Future<List<Site>> getSites() async {
    final response = await _dio.get('/api/admin/sites');
    if (response.statusCode == 200 && response.data != null) {
      final list = response.data as List<dynamic>;
      return list
          .map((e) => Site.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_errorMessage(response.data, '获取站点列表失败'));
  }

  Future<Site> createSite(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/admin/sites', data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Site.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception(_errorMessage(response.data, '创建站点失败'));
  }

  Future<Site> updateSite(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/api/admin/sites/$id', data: data);
    if (response.statusCode == 200) {
      return Site.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception(_errorMessage(response.data, '更新站点失败'));
  }

  Future<List<Conversation>> getConversations({
    String? agentId,
    String? groupId,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final queryParams = <String, dynamic>{};
    if (agentId != null) queryParams['agentId'] = agentId;
    if (groupId != null) queryParams['groupId'] = groupId;
    if (startAt != null) queryParams['startAt'] = startAt.toIso8601String();
    if (endAt != null) queryParams['endAt'] = endAt.toIso8601String();

    final response = await _dio.get(
      '/api/admin/conversations',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200 && response.data != null) {
      final list = response.data as List<dynamic>;
      return list
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_errorMessage(response.data, '获取咨询列表失败'));
  }

  Future<AdminConversationDetail> getConversationDetail(String id) async {
    final response = await _dio.get('/api/admin/conversations/$id');
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>? ?? [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return AdminConversationDetail(
        conversation:
            Conversation.fromJson(data['conversation'] as Map<String, dynamic>),
        messages: messages,
      );
    }
    throw Exception(_errorMessage(response.data, '获取会话详情失败'));
  }

  String _errorMessage(dynamic data, String fallback) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
      final error = data['error'];
      if (error is String && error.isNotEmpty) return error;
    }
    return fallback;
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AdminRepository(dio);
});
