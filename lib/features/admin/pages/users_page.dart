import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/group.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/admin_providers.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminUsersProvider.notifier).loadUsers();
      ref.read(adminGroupsProvider.notifier).loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersProvider);

    if (state.isLoading && state.users.isEmpty) {
      return const Center(child: LoadingIndicator());
    }

    if (state.error != null && state.users.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(adminUsersProvider.notifier).loadUsers(),
      );
    }

    return Scaffold(
      body: state.users.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline,
              title: '暂无账号',
              subtitle: '点击右下角添加账号',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildUserCard(context, state.users[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, AdminUser user) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAdmin = user.role == 'ADMIN';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            UserAvatar(
              name: user.name,
              imageUrl: user.avatarUrl,
              size: 48,
              showStatus: true,
              status: user.agentStatus == 'ONLINE' ? 'online' : 'offline',
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
                          user.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? colorScheme.primaryContainer
                              : colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isAdmin ? '管理员' : '坐席',
                          style: TextStyle(
                            fontSize: 10,
                            color: isAdmin
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
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

  void _showUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'AGENT';
    String? groupId;
    final formKey = GlobalKey<FormState>();

    final groups = ref.read(adminGroupsProvider).groups;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加账号'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '姓名',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v?.isEmpty == true ? '请输入姓名' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v?.isEmpty == true) return '请输入邮箱';
                      if (!v!.contains('@')) return '请输入有效邮箱';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    obscureText: true,
                    validator: (v) =>
                        (v?.length ?? 0) < 8 ? '密码至少8位' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(
                      labelText: '角色',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'AGENT',
                        child: Text('客服坐席'),
                      ),
                      DropdownMenuItem(
                        value: 'ADMIN',
                        child: Text('管理员'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => role = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: groupId,
                    decoration: const InputDecoration(
                      labelText: '所属分组（可选）',
                      prefixIcon: Icon(Icons.group_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('不分配'),
                      ),
                      ...groups.map(
                        (g) => DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(g.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => groupId = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) return;

                final success = await ref
                    .read(adminUsersProvider.notifier)
                    .createUser({
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'password': passwordController.text,
                  'role': role,
                  if (groupId != null) 'groupId': groupId,
                });

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '添加成功' : '添加失败，请重试'),
                    backgroundColor: success
                        ? null
                        : Theme.of(context).colorScheme.error,
                  ),
                );
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}
