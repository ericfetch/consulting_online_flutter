import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/admin_providers.dart';

class AdminConversationsPage extends ConsumerStatefulWidget {
  const AdminConversationsPage({super.key});

  @override
  ConsumerState<AdminConversationsPage> createState() =>
      _AdminConversationsPageState();
}

class _AdminConversationsPageState extends ConsumerState<AdminConversationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminConversationsProvider.notifier).loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminConversationsProvider);

    return Column(
      children: [
        _buildFilterBar(context, state),
        Expanded(
          child: state.isLoading && state.conversations.isEmpty
              ? const Center(child: LoadingIndicator())
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(adminConversationsProvider.notifier)
                      .loadConversations(),
                  child: state.conversations.isEmpty
                      ? (state.error != null
                          ? ErrorState(
                              message: state.error!,
                              onRetry: () => ref
                                  .read(adminConversationsProvider.notifier)
                                  .loadConversations(),
                            )
                          : const EmptyState(
                              icon: Icons.chat_bubble_outline,
                              title: '暂无咨询记录',
                            ))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.conversations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildConversationCard(
                              context, state.conversations[index]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, AdminConversationsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: '全部',
              selected: state.filter == 'all',
              onTap: () => ref
                  .read(adminConversationsProvider.notifier)
                  .setFilter('all'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: '今天',
              selected: state.filter == 'today',
              onTap: () => ref
                  .read(adminConversationsProvider.notifier)
                  .setFilter('today'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: '近7天',
              selected: state.filter == 'week',
              onTap: () => ref
                  .read(adminConversationsProvider.notifier)
                  .setFilter('week'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: '近30天',
              selected: state.filter == 'month',
              onTap: () => ref
                  .read(adminConversationsProvider.notifier)
                  .setFilter('month'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }

  Widget _buildConversationCard(BuildContext context, Conversation conv) {
    final colorScheme = Theme.of(context).colorScheme;
    final visitorName =
        conv.visitorName.isNotEmpty ? conv.visitorName : '访客';

    return Card(
      child: InkWell(
        onTap: () => _showDetail(context, conv),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    name: visitorName,
                    imageUrl: conv.visitorAvatarUrl,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                visitorName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(conv.visitorPresence),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${conv.siteName.isNotEmpty ? conv.siteName : '未知站点'} · ${AppDateUtils.formatDateTime(conv.lastMessageAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (conv.assigneeName?.isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        conv.assigneeName!,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(VisitorPresence presence) {
    final (label, color) = _presenceInfo(presence);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  (String, Color) _presenceInfo(VisitorPresence presence) {
    switch (presence) {
      case VisitorPresence.active:
      case VisitorPresence.away:
        return ('进行中', const Color(0xFF10B981));
      case VisitorPresence.browsing:
        return ('浏览中', Colors.blue);
      case VisitorPresence.widgetClosed:
      case VisitorPresence.siteClosed:
        return ('已离开', Colors.grey);
    }
  }

  void _showDetail(BuildContext context, Conversation conv) {
    final future =
        ref.read(adminRepositoryProvider).getConversationDetail(conv.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => FutureBuilder<AdminConversationDetail>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: LoadingIndicator());
            }
            if (snapshot.hasError) {
              return const ErrorState(message: '加载详情失败');
            }
            final detail = snapshot.data!;
            return _buildDetail(context, detail.conversation, detail.messages,
                scrollController);
          },
        ),
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    Conversation conv,
    List<ChatMessage> messages,
    ScrollController scrollController,
  ) {
    final visitorName = conv.visitorName.isNotEmpty ? conv.visitorName : '访客';

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('会话详情', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                _buildDetailRow('访客', visitorName),
                _buildDetailRow('状态', _presenceLabel(conv.visitorPresence)),
                _buildDetailRow('站点', conv.siteName.isNotEmpty ? conv.siteName : '未知'),
                if (conv.assigneeName?.isNotEmpty == true)
                  _buildDetailRow('坐席', conv.assigneeName!),
                if (conv.visitorIp.isNotEmpty)
                  _buildDetailRow('IP', conv.visitorIp),
                if (conv.visitorIpLocation.isNotEmpty)
                  _buildDetailRow('位置', conv.visitorIpLocation),
                if (conv.landingUrl.isNotEmpty)
                  _buildDetailRow('页面', conv.landingUrl),
                _buildDetailRow(
                    '时间', AppDateUtils.formatDateTime(conv.createdAt)),
                const Divider(height: 32),
                Text(
                  '消息记录（${messages.length}）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...messages.map((m) => _buildMessageTile(context, m)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(BuildContext context, ChatMessage message) {
    final isAgent = message.isFromAgent;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isAgent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAgent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAgent
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(message.displayContent),
                ),
                const SizedBox(height: 2),
                Text(
                  AppDateUtils.formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _presenceLabel(VisitorPresence presence) {
    return _presenceInfo(presence).$1;
  }
}
