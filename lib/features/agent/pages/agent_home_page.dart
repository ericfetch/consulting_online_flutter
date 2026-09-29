import 'package:flutter/material.dart';
import '../../customers/customer_pages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/agent_providers.dart';
import 'conversations_page.dart';
import 'settings_page.dart';

class AgentHomePage extends ConsumerStatefulWidget {
  const AgentHomePage({super.key});

  @override
  ConsumerState<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends ConsumerState<AgentHomePage> {
  int _currentIndex = 0;

  String _getStatusString(AgentStatus? status) {
    switch (status) {
      case AgentStatus.online:
        return 'online';
      case AgentStatus.busy:
        return 'busy';
      case AgentStatus.offline:
      default:
        return 'offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final appState = ref.watch(agentAppProvider);
    final settings = appState.settings;
    final unreadCount =
        appState.unreadCounts.values.fold<int>(0, (sum, count) => sum + count);
    final currentStatus = _getStatusString(settings?.agentStatus);

    ref.listen<String?>(
      agentAppProvider.select((s) => s.error),
      (previous, next) {
        if (next != null && next.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          ref.read(agentAppProvider.notifier).setError(null);
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? '客服工作台' : '设置'),
        actions: [
          IconButton(
              tooltip: '客户资料',
              icon: const Icon(Icons.folder_shared_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CustomerListPage()))),
          if (_currentIndex == 0) _buildStatusSelector(currentStatus),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          PopupMenuButton<String>(
            icon: UserAvatar(
              name: user?.name,
              imageUrl: user?.avatarUrl,
              size: 32,
              showStatus: true,
              status: currentStatus,
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              } else if (value == 'settings') {
                setState(() => _currentIndex = 1);
              } else if (value == 'admin') {
                context.go('/admin');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  user?.name ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const PopupMenuDivider(),
              if (user?.isAdmin == true)
                const PopupMenuItem(
                  value: 'admin',
                  child: ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text('管理后台'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('个人设置'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('退出登录', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [ConversationsPage(), SettingsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: Badge(
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: Badge(
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.chat_bubble),
            ),
            label: '会话',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector(String currentStatus) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = {
      'online': const Color(0xFF10B981),
      'busy': const Color(0xFFF59E0B),
      'offline': const Color(0xFF9CA3AF),
    };
    final statusLabels = {'online': '在线', 'busy': '忙碌', 'offline': '离线'};
    final statusIcons = {
      'online': Icons.circle,
      'busy': Icons.do_not_disturb_on,
      'offline': Icons.cancel_outlined,
    };

    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: statusColors[currentStatus]?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              statusIcons[currentStatus] ?? Icons.circle,
              size: 12,
              color: statusColors[currentStatus],
            ),
            const SizedBox(width: 6),
            Text(
              statusLabels[currentStatus] ?? '在线',
              style: TextStyle(
                color: statusColors[currentStatus],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      onSelected: (status) {
        AgentStatus agentStatus;
        switch (status) {
          case 'online':
            agentStatus = AgentStatus.online;
            break;
          case 'busy':
            agentStatus = AgentStatus.busy;
            break;
          case 'offline':
          default:
            agentStatus = AgentStatus.offline;
        }
        ref.read(agentAppProvider.notifier).updateStatus(agentStatus);
      },
      itemBuilder: (context) => [
        _buildStatusItem(
          'online',
          '在线',
          statusColors['online']!,
          statusIcons['online']!,
        ),
        _buildStatusItem(
          'busy',
          '忙碌',
          statusColors['busy']!,
          statusIcons['busy']!,
        ),
        _buildStatusItem(
          'offline',
          '离线',
          statusColors['offline']!,
          statusIcons['offline']!,
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildStatusItem(
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
