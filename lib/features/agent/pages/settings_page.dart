import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/agent_providers.dart';
import '../providers/agent_utils.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final appState = ref.watch(agentAppProvider);
    final settings = appState.settings;
    final colorScheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);

    if (settings == null) {
      return const Center(child: LoadingIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProfileCard(context, user, colorScheme),
        const SizedBox(height: 20),
        _buildSectionTitle(context, '坐席状态'),
        _buildStatusSelector(context, ref, settings.agentStatus),
        const SizedBox(height: 20),
        _buildSectionTitle(context, '偏好设置'),
        Card(
          child: Column(
            children: [
              _buildSwitchTile(
                icon: Icons.translate,
                title: '自动翻译',
                subtitle: '自动翻译访客消息',
                value: settings.autoTranslate,
                onChanged: (value) {
                  ref.read(agentAppProvider.notifier).updateSettings({
                    'autoTranslate': value,
                  });
                },
              ),
              _buildDivider(context),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('主题模式'),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('跟随系统'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('亮色模式'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('暗色模式'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
              ),
              _buildDivider(context),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('通知设置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showNotificationSettings(context);
                },
              ),
              _buildDivider(context),
              ListTile(
                leading: const Icon(Icons.quickreply_outlined),
                title: const Text('快捷回复管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showQuickRepliesEditor(context, ref, appState.quickReplies);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle(context, '自动问候'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.autoGreeting ?? '您好，我是在线客服，有什么可以帮您？',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    _showEditGreetingDialog(
                      context,
                      ref,
                      settings.autoGreeting,
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('编辑问候语'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle(context, '可见站点'),
        if (settings.visibleSites.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  '暂无可见站点',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: settings.visibleSites.asMap().entries.map((entry) {
                final site = entry.value;
                final isLast = entry.key == settings.visibleSites.length - 1;
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: Text(siteDisplayName(site)),
                      subtitle: site.companyName.isNotEmpty
                          ? Text(site.companyName)
                          : null,
                      trailing: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: site.enabled ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                    if (!isLast) _buildDivider(context),
                  ],
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 20),
        _buildSectionTitle(context, '关于'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('版本'),
                trailing: Text(
                  '1.0.0',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    AgentUser? user,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            UserAvatar(
              name: user?.name ?? '',
              imageUrl: user?.avatarUrl,
              size: 64,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user?.isAdmin == true ? '管理员' : '客服坐席',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildStatusSelector(
    BuildContext context,
    WidgetRef ref,
    AgentStatus currentStatus,
  ) {
    final statuses = [
      (AgentStatus.online, '在线', const Color(0xFF10B981), Icons.circle),
      (
        AgentStatus.busy,
        '忙碌',
        const Color(0xFFF59E0B),
        Icons.do_not_disturb_on,
      ),
      (
        AgentStatus.offline,
        '离线',
        const Color(0xFF9CA3AF),
        Icons.cancel_outlined,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: statuses.map((s) {
            final isSelected = s.$1 == currentStatus;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  ref.read(agentAppProvider.notifier).updateStatus(s.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  margin: EdgeInsets.only(
                    right: s.$1 != AgentStatus.offline ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? s.$3.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? s.$3
                          : Theme.of(context).dividerTheme.color ??
                              Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(s.$4, color: s.$3, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        s.$2,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? s.$3 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      color: Theme.of(context).dividerTheme.color,
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Text(
              '通知设置',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const SwitchListTile(
              secondary: Icon(Icons.notifications_active_outlined),
              title: Text('新消息通知'),
              value: true,
              onChanged: null,
            ),
            const SwitchListTile(
              secondary: Icon(Icons.volume_up_outlined),
              title: Text('提示音'),
              value: true,
              onChanged: null,
            ),
            const SwitchListTile(
              secondary: Icon(Icons.vibration),
              title: Text('震动反馈'),
              value: true,
              onChanged: null,
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickRepliesEditor(
      BuildContext context, WidgetRef ref, List<String> replies) {
    final controller = TextEditingController(text: replies.join('\n'));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('管理快捷回复'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('每行一条快捷回复',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '输入快捷回复，每行一条',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final newReplies = controller.text
                  .split('\n')
                  .where((r) => r.trim().isNotEmpty)
                  .toList();
              ref.read(agentAppProvider.notifier).saveQuickReplies(newReplies);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showEditGreetingDialog(
    BuildContext context,
    WidgetRef ref,
    String? currentGreeting,
  ) {
    final controller = TextEditingController(text: currentGreeting ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑自动问候语'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '输入自动问候语',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(agentAppProvider.notifier).updateSettings({
                'autoGreeting': controller.text.trim(),
              });
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
