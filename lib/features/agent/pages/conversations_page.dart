import 'package:flutter/material.dart';
import '../../customers/customer_status_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/conversation.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/agent_providers.dart';
import '../providers/agent_utils.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _getTabIndex(ConversationBucket mode) {
    switch (mode) {
      case ConversationBucket.serving:
        return 0;
      case ConversationBucket.browsing:
        return 1;
      case ConversationBucket.left:
        return 2;
    }
  }

  ConversationBucket _getBucketFromIndex(int index) {
    switch (index) {
      case 0:
        return ConversationBucket.serving;
      case 1:
        return ConversationBucket.browsing;
      case 2:
      default:
        return ConversationBucket.left;
    }
  }

  List<Conversation> _getConversationsForBucket(
      AgentAppState state, ConversationBucket bucket) {
    return state.assignedConversations.where((item) {
      final p = state.presence[item.id];
      final s = effectivePresenceState(item, p, state.presenceClock);
      return conversationBucket(s, item) == bucket;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(agentAppProvider);
    final counts = appState.bucketCounts;
    final servingConversations =
        _getConversationsForBucket(appState, ConversationBucket.serving);
    final browsingConversations =
        _getConversationsForBucket(appState, ConversationBucket.browsing);
    final closedConversations =
        _getConversationsForBucket(appState, ConversationBucket.left);

    ref.listen<ConversationBucket>(
      agentAppProvider.select((s) => s.queueMode),
      (previous, next) {
        _tabController.animateTo(_getTabIndex(next));
      },
    );

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color:
                    Theme.of(context).dividerTheme.color ?? Colors.transparent,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            onTap: (index) {
              ref
                  .read(agentAppProvider.notifier)
                  .setQueueMode(_getBucketFromIndex(index));
            },
            tabs: [
              _buildTab('接待中', counts[ConversationBucket.serving] ?? 0),
              _buildTab('浏览中', counts[ConversationBucket.browsing] ?? 0),
              _buildTab('已离开', counts[ConversationBucket.left] ?? 0),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildConversationList(
                  servingConversations, '暂无接待中的会话', appState),
              _buildConversationList(
                browsingConversations,
                '暂无浏览中的访客',
                appState,
              ),
              _buildConversationList(closedConversations, '暂无历史会话', appState),
            ],
          ),
        ),
      ],
    );
  }

  Tab _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationList(
    List<Conversation> conversations,
    String emptyText,
    AgentAppState appState,
  ) {
    if (conversations.isEmpty) {
      return _EmptyConversations(text: emptyText);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _ConversationTile(
          conversation: conversation,
          appState: appState,
        );
      },
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  final String text;
  const _EmptyConversations({required this.text});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Conversation conversation;
  final AgentAppState appState;

  const _ConversationTile({required this.conversation, required this.appState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = appState.selectedId == conversation.id;
    final recordStatus = ref.watch(customerStatusesProvider)[conversation.id];
    final colorScheme = Theme.of(context).colorScheme;
    final presenceInfo = appState.presence[conversation.id];
    final presenceState = effectivePresenceState(
        conversation, presenceInfo, appState.presenceClock);
    final bucket = conversationBucket(presenceState, conversation);
    final draft = appState.drafts[conversation.id] ?? '';
    final isVisitorTyping = draft.isNotEmpty;
    final unreadCount = appState.unreadCounts[conversation.id] ?? 0;
    final hasUnread = unreadCount > 0;
    final latestUnread = appState.latestUnreadMessages[conversation.id];
    final displayName = visitorDisplayName(conversation);

    return InkWell(
      onTap: () => _openChat(context, ref),
      child: Container(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildVisitorAvatar(context, displayName, presenceState),
                if (isVisitorTyping)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        AppDateUtils.formatRelativeTime(
                          conversation.lastMessageAt,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: isVisitorTyping
                            ? Text(
                                '正在输入：$draft',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.infoColor,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                visitorListPreview(conversation, presenceState,
                                    latestUnread, null),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: hasUnread
                                      ? colorScheme.onSurface
                                      : colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStatusBadge(context, bucket),
                      if (recordStatus is Map &&
                          recordStatus['submitted'] == true)
                        Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text('已提交',
                                style: TextStyle(
                                    fontSize: 11, color: colorScheme.primary))),
                      if (recordStatus is Map &&
                          recordStatus['summarized'] == true)
                        Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text('已汇总',
                                style: TextStyle(
                                    fontSize: 11, color: colorScheme.primary))),
                      if (conversation.siteName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.language,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            conversation.siteName,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorAvatar(
      BuildContext context, String name, VisitorPresence state) {
    if (conversation.visitorAvatarUrl.isNotEmpty) {
      return UserAvatar(
        name: name,
        imageUrl: conversation.visitorAvatarUrl,
        size: 48,
        showStatus: true,
        status: _getPresenceStatus(state),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getAvatarColor(),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          conversation.visitorInitial,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Color _getAvatarColor() {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
    ];
    final index = conversation.id.hashCode.abs() % colors.length;
    return colors[index].withValues(alpha: 0.2);
  }

  String _getPresenceStatus(VisitorPresence state) {
    switch (state) {
      case VisitorPresence.active:
      case VisitorPresence.away:
        return 'online';
      case VisitorPresence.browsing:
        return 'busy';
      case VisitorPresence.widgetClosed:
      case VisitorPresence.siteClosed:
        return 'offline';
    }
  }

  Widget _buildStatusBadge(BuildContext context, ConversationBucket bucket) {
    final colorScheme = Theme.of(context).colorScheme;
    Color bgColor;
    Color textColor;
    String label;

    switch (bucket) {
      case ConversationBucket.serving:
        bgColor = AppTheme.successColor.withValues(alpha: 0.1);
        textColor = AppTheme.successColor;
        label = conversation.status == 'RESOLVED' ? '已结束' : '接待中';
        break;
      case ConversationBucket.browsing:
        bgColor = AppTheme.infoColor.withValues(alpha: 0.1);
        textColor = AppTheme.infoColor;
        label = '浏览中';
        break;
      case ConversationBucket.left:
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        label = conversation.status == 'RESOLVED' ? '已结束' : '已离开';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _openChat(BuildContext context, WidgetRef ref) {
    ref.read(agentAppProvider.notifier).selectConversation(conversation.id);
    context.push('/agent/chat/${conversation.id}');
  }
}
