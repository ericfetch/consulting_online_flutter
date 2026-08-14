import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/admin_providers.dart';
import 'dashboard_page.dart';
import 'conversations_page.dart';
import 'users_page.dart';
import 'groups_page.dart';
import 'sites_page.dart';

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  int _currentIndex = 0;

  final _pages = const [
    DashboardPage(),
    AdminConversationsPage(),
    UsersPage(),
    GroupsPage(),
    SitesPage(),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dashboardProvider.notifier).loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理后台'),
        actions: [
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
            ),
            onSelected: (value) {
              if (value == 'switch_to_agent') {
                context.go('/agent');
              } else if (value == 'logout') {
                _handleLogout();
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
              const PopupMenuItem(
                value: 'switch_to_agent',
                child: ListTile(
                  leading: Icon(Icons.headset_mic_outlined),
                  title: Text('切换到工作台'),
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
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _loadPageData(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '仪表盘',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '咨询',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: '账号',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_work_outlined),
            selectedIcon: Icon(Icons.group_work),
            label: '分组',
          ),
          NavigationDestination(
            icon: Icon(Icons.web_outlined),
            selectedIcon: Icon(Icons.web),
            label: '站点',
          ),
        ],
      ),
    );
  }

  void _loadPageData(int index) {
    switch (index) {
      case 0:
        ref.read(dashboardProvider.notifier).loadStats();
        break;
      case 1:
        ref.read(adminConversationsProvider.notifier).loadConversations();
        break;
      case 2:
        ref.read(adminUsersProvider.notifier).loadUsers();
        break;
      case 3:
        ref.read(adminGroupsProvider.notifier).loadGroups();
        break;
      case 4:
        ref.read(adminSitesProvider.notifier).loadSites();
        break;
    }
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
