import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/group.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/admin_providers.dart';

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminGroupsProvider.notifier).loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminGroupsProvider);

    if (state.isLoading && state.groups.isEmpty) {
      return const Center(child: LoadingIndicator());
    }

    if (state.error != null && state.groups.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(adminGroupsProvider.notifier).loadGroups(),
      );
    }

    return Scaffold(
      body: state.groups.isEmpty
          ? const EmptyState(
              icon: Icons.group_work_outlined,
              title: '暂无分组',
              subtitle: '点击右下角添加坐席分组',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildGroupCard(context, state.groups[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGroupDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, AgentGroup group) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.group, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (group.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      group.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    group.assignmentRuleLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showGroupDialog(context, group: group);
                } else if (value == 'delete') {
                  _showDeleteDialog(context, group);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('编辑'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('删除', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupDialog(BuildContext context, {AgentGroup? group}) {
    final nameController = TextEditingController(text: group?.name);
    final descController = TextEditingController(text: group?.description);
    AssignmentRule rule = group?.assignmentRule ?? AssignmentRule.average;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(group == null ? '添加分组' : '编辑分组'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '分组名称',
                      prefixIcon: Icon(Icons.group_outlined),
                    ),
                    validator: (v) => v?.isEmpty == true ? '请输入分组名称' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: '描述（可选）',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AssignmentRule>(
                    value: rule,
                    decoration: const InputDecoration(
                      labelText: '分配规则',
                      prefixIcon: Icon(Icons.rule_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: AssignmentRule.average,
                        child: Text('平均分配'),
                      ),
                      DropdownMenuItem(
                        value: AssignmentRule.sequential,
                        child: Text('顺序分配'),
                      ),
                      DropdownMenuItem(
                        value: AssignmentRule.conversionRate,
                        child: Text('按转化率'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => rule = value);
                    },
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

                final data = {
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'assignmentRule': assignmentRuleToApi(rule),
                };

                final notifier = ref.read(adminGroupsProvider.notifier);
                final success = group == null
                    ? await notifier.createGroup(data)
                    : await notifier.updateGroup(group.id, data);

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? (group == null ? '添加成功' : '更新成功')
                          : '操作失败，请重试',
                    ),
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

  void _showDeleteDialog(BuildContext context, AgentGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定要删除分组「${group.name}」吗？分组下的坐席和会话将变为未分配。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await ref
                  .read(adminGroupsProvider.notifier)
                  .deleteGroup(group.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? '删除成功' : '删除失败，请重试'),
                  backgroundColor: success
                      ? null
                      : Theme.of(context).colorScheme.error,
                ),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
