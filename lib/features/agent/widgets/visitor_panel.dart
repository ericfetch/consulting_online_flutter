import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/conversation.dart';
import '../providers/agent_utils.dart';

class VisitorPanel extends StatelessWidget {
  final Conversation conversation;
  final VisitorPresence? presenceState;

  const VisitorPanel({
    super.key,
    required this.conversation,
    this.presenceState,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveState = effectivePresenceState(
      conversation,
      presenceState != null ? PresenceInfo(state: presenceState!) : null,
      DateTime.now(),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildVisitorHeader(context, effectiveState),
                    const SizedBox(height: 24),
                    _buildStatusSection(context),
                    const SizedBox(height: 24),
                    _buildInfoSection(context),
                    if (conversation.formData != null &&
                        conversation.formData!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildFormDataSection(context),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitorHeader(BuildContext context, VisitorPresence state) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = visitorDisplayName(conversation);

    return Column(
      children: [
        _buildVisitorAvatar(context),
        const SizedBox(height: 12),
        Text(
          displayName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(state).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            presenceLabel(state).isNotEmpty ? presenceLabel(state) : '未知状态',
            style: TextStyle(
              fontSize: 13,
              color: _getStatusColor(state),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitorAvatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (conversation.visitorAvatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(conversation.visitorAvatarUrl),
        backgroundColor: colorScheme.primaryContainer,
      );
    }
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          conversation.visitorInitial,
          style: const TextStyle(fontSize: 36),
        ),
      ),
    );
  }

  Color _getStatusColor(VisitorPresence state) {
    final bucket = conversationBucket(state, conversation);
    switch (bucket) {
      case ConversationBucket.serving:
        return AppTheme.successColor;
      case ConversationBucket.browsing:
        return AppTheme.infoColor;
      case ConversationBucket.left:
        return Colors.grey;
    }
  }

  Widget _buildStatusSection(BuildContext context) {
    return _buildSection(
      context,
      title: '状态信息',
      icon: Icons.info_outline,
      children: [
        _buildInfoRow(
          context,
          label: '会话状态',
          value: _getConversationStatusLabel(),
        ),
        _buildInfoRow(
          context,
          label: '接入时间',
          value: AppDateUtils.formatDateTime(conversation.createdAt),
        ),
        _buildInfoRow(
          context,
          label: '最后消息',
          value: AppDateUtils.formatRelativeTime(conversation.lastMessageAt),
        ),
        if (conversation.assigneeName != null &&
            conversation.assigneeName!.isNotEmpty)
          _buildInfoRow(
            context,
            label: '接待坐席',
            value: conversation.assigneeName!,
          ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final List<Widget> children = [];

    if (conversation.siteName.isNotEmpty) {
      children.add(
        _buildInfoRow(
          context,
          label: '来源站点',
          value: conversation.siteName,
          icon: Icons.language,
        ),
      );
    }
    if (conversation.companyName.isNotEmpty) {
      children.add(
        _buildInfoRow(
          context,
          label: '公司名称',
          value: conversation.companyName,
          icon: Icons.business,
        ),
      );
    }
    if (conversation.visitorPhone.isNotEmpty) {
      children.add(
        _buildInfoRow(
          context,
          label: '手机号',
          value: conversation.visitorPhone,
          icon: Icons.phone,
        ),
      );
    }
    if (conversation.visitorIpLocation.isNotEmpty) {
      children.add(
        _buildInfoRow(
          context,
          label: 'IP归属地',
          value: conversation.visitorIpLocation,
          icon: Icons.location_on_outlined,
        ),
      );
    }
    if (conversation.visitorLanguage.isNotEmpty) {
      children.add(
        _buildInfoRow(
          context,
          label: '语言',
          value: conversation.visitorLanguage,
          icon: Icons.translate,
        ),
      );
    }
    if (conversation.landingUrl.isNotEmpty) {
      children.add(
        _buildInfoRow(
          context,
          label: '当前页面',
          value: conversation.landingUrl,
          icon: Icons.link,
          isUrl: true,
        ),
      );
    }
    if (conversation.referrer.isNotEmpty) {
      children.add(
        _buildInfoRow(
          context,
          label: '来源页面',
          value: conversation.referrer,
          icon: Icons.arrow_forward,
          isUrl: true,
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      context,
      title: '访客信息',
      icon: Icons.person_outline,
      children: children,
    );
  }

  Widget _buildFormDataSection(BuildContext context) {
    final formData = conversation.formData!;
    final List<Widget> children = formData.entries.map((entry) {
      return _buildInfoRow(
        context,
        label: entry.key,
        value: entry.value?.toString() ?? '',
      );
    }).toList();

    return _buildSection(
      context,
      title: '表单信息',
      icon: Icons.edit_note,
      children: children,
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
    bool isUrl = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isUrl ? colorScheme.primary : colorScheme.onSurface,
                decoration: isUrl ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getConversationStatusLabel() {
    switch (conversation.status) {
      case 'OPEN':
        return '进行中';
      case 'PENDING':
        return '待处理';
      case 'RESOLVED':
        return '已结束';
      default:
        return conversation.status;
    }
  }
}
