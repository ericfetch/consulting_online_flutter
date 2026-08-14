import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/site.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/admin_providers.dart';

class SitesPage extends ConsumerStatefulWidget {
  const SitesPage({super.key});

  @override
  ConsumerState<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends ConsumerState<SitesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminSitesProvider.notifier).loadSites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSitesProvider);

    if (state.isLoading && state.sites.isEmpty) {
      return const Center(child: LoadingIndicator());
    }

    if (state.error != null && state.sites.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(adminSitesProvider.notifier).loadSites(),
      );
    }

    return Scaffold(
      body: state.sites.isEmpty
          ? const EmptyState(
              icon: Icons.web_outlined,
              title: '暂无站点',
              subtitle: '点击右下角添加站点',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.sites.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildSiteCard(context, state.sites[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSiteDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSiteCard(BuildContext context, Site site) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            site.whatsappConfig?.enabled == true ? Icons.phone : Icons.web,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                site.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: site.enabled
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                site.enabled ? '启用' : '停用',
                style: TextStyle(
                  fontSize: 10,
                  color: site.enabled
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          site.domain.isNotEmpty ? site.domain : site.companyName,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showSiteDialog(context, site: site);
            } else if (value == 'config_llm') {
              _showLlmConfigDialog(context, site);
            } else if (value == 'config_whatsapp') {
              _showWhatsAppConfigDialog(context, site);
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
              value: 'config_llm',
              child: ListTile(
                leading: Icon(Icons.psychology_outlined),
                title: Text('LLM配置'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'config_whatsapp',
              child: ListTile(
                leading: Icon(Icons.chat_outlined),
                title: Text('WhatsApp配置'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          _buildConfigStatus(
            icon: Icons.psychology,
            title: 'AI 智能能力',
            enabled: site.llmConfig?.enabled ?? false,
            subtitle: site.llmConfig?.model.isNotEmpty == true
                ? site.llmConfig!.model
                : '未配置',
          ),
          const SizedBox(height: 8),
          _buildConfigStatus(
            icon: Icons.chat,
            title: 'WhatsApp 接入',
            enabled: site.whatsappConfig?.enabled ?? false,
            subtitle: site.whatsappConfig?.phoneNumberId.isNotEmpty == true
                ? site.whatsappConfig!.phoneNumberId
                : '未配置',
          ),
        ],
      ),
    );
  }

  Widget _buildConfigStatus({
    required IconData icon,
    required String title,
    required bool enabled,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: enabled ? Colors.green : Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            enabled ? '已启用' : '未启用',
            style: TextStyle(
              fontSize: 11,
              color: enabled ? Colors.green : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  void _showSiteDialog(BuildContext context, {Site? site}) {
    final nameController = TextEditingController(text: site?.name);
    final companyController = TextEditingController(text: site?.companyName);
    final domainController = TextEditingController(text: site?.domain);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(site == null ? '添加站点' : '编辑站点'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '站点名称',
                    prefixIcon: Icon(Icons.web_outlined),
                  ),
                  validator: (v) => v?.isEmpty == true ? '请输入站点名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: companyController,
                  decoration: const InputDecoration(
                    labelText: '企业名称（可选）',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: domainController,
                  decoration: const InputDecoration(
                    labelText: '域名（可选）',
                    prefixIcon: Icon(Icons.link),
                    hintText: 'example.com',
                  ),
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
                'companyName': companyController.text.trim(),
                'domain': domainController.text.trim(),
              };

              final notifier = ref.read(adminSitesProvider.notifier);
              final success = site == null
                  ? await notifier.createSite(data)
                  : await notifier.updateSite(site.id, data);

              if (!context.mounted) return;
              Navigator.pop(context);
              _showResultSnackBar(
                success,
                site == null ? '添加成功' : '更新成功',
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showLlmConfigDialog(BuildContext context, Site site) {
    final llm = site.llmConfig;
    final apiKeyController = TextEditingController(text: llm?.apiKey ?? '');
    final modelController =
        TextEditingController(text: llm?.model ?? 'gpt-4o-mini');
    final baseUrlController = TextEditingController(
      text: llm?.baseUrl ?? 'https://api.openai.com/v1',
    );
    bool enabled = llm?.enabled ?? false;
    bool isClaude = llm?.provider == LlmProvider.claude;
    bool intentAnalysis = llm?.intentAnalysis ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('LLM 配置'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('启用 AI 能力'),
                    value: enabled,
                    onChanged: (v) => setState(() => enabled = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  DropdownButtonFormField<bool>(
                    value: isClaude,
                    decoration: const InputDecoration(labelText: '服务提供商'),
                    items: const [
                      DropdownMenuItem(value: false, child: Text('OpenAI')),
                      DropdownMenuItem(value: true, child: Text('Claude')),
                    ],
                    onChanged: (v) => setState(() => isClaude = v ?? false),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      prefixIcon: const Icon(Icons.key_outlined),
                      helperText: apiKeyController.text.startsWith('****')
                          ? '已加密保存，留空保持不变'
                          : null,
                    ),
                    obscureText: true,
                    validator: (v) =>
                        enabled && (v?.isEmpty == true) ? '启用时需填写 API Key' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: modelController,
                    decoration: const InputDecoration(
                      labelText: '模型名称',
                      prefixIcon: Icon(Icons.memory_outlined),
                      hintText: 'gpt-4o-mini',
                    ),
                    validator: (v) =>
                        enabled && (v?.isEmpty == true) ? '启用时需填写模型' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'API 地址',
                      prefixIcon: Icon(Icons.link),
                    ),
                    validator: (v) =>
                        enabled && (v?.isEmpty == true) ? '启用时需填写地址' : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('意图识别'),
                    subtitle: const Text('自动识别访客消息意图'),
                    value: intentAnalysis,
                    onChanged: (v) => setState(() => intentAnalysis = v),
                    contentPadding: EdgeInsets.zero,
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

                final apiKey = apiKeyController.text.trim();
                final model = modelController.text.trim();
                final baseUrl = baseUrlController.text.trim();

                // 后端 llmConfig 要求 apiKey/model/baseUrl 非空；未启用且无密钥时直接省略该配置。
                if (!enabled && apiKey.isEmpty) {
                  Navigator.pop(context);
                  return;
                }

                final success = await ref
                    .read(adminSitesProvider.notifier)
                    .updateSite(site.id, {
                  'llmConfig': {
                    'enabled': enabled,
                    'provider': isClaude ? 'claude' : 'openai',
                    'apiKey': apiKey,
                    'model': model,
                    'baseUrl': baseUrl,
                    'intentAnalysis': intentAnalysis,
                  },
                });

                if (!context.mounted) return;
                Navigator.pop(context);
                _showResultSnackBar(success, '配置已保存');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWhatsAppConfigDialog(BuildContext context, Site site) {
    final wa = site.whatsappConfig;
    final phoneIdController = TextEditingController(text: wa?.phoneNumberId ?? '');
    final businessIdController =
        TextEditingController(text: wa?.businessAccountId ?? '');
    final displayPhoneController =
        TextEditingController(text: wa?.displayPhoneNumber ?? '');
    final tokenController = TextEditingController(text: wa?.accessToken ?? '');
    final secretController = TextEditingController(text: wa?.appSecret ?? '');
    final verifyController = TextEditingController(text: wa?.verifyToken ?? '');
    final versionController =
        TextEditingController(text: wa?.apiVersion ?? 'v26.0');
    bool enabled = wa?.enabled ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('WhatsApp 配置'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('启用 WhatsApp'),
                    value: enabled,
                    onChanged: (v) => setState(() => enabled = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneIdController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number ID',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) =>
                        enabled && (v?.isEmpty == true) ? '启用时需填写' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: businessIdController,
                    decoration: const InputDecoration(
                      labelText: 'Business Account ID（可选）',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: displayPhoneController,
                    decoration: const InputDecoration(
                      labelText: '显示号码（可选）',
                      prefixIcon: Icon(Icons.contact_phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: tokenController,
                    decoration: InputDecoration(
                      labelText: 'Access Token',
                      prefixIcon: const Icon(Icons.key_outlined),
                      helperText: tokenController.text.startsWith('****')
                          ? '已加密保存，留空保持不变'
                          : null,
                    ),
                    obscureText: true,
                    validator: (v) =>
                        enabled && (v?.isEmpty == true) ? '启用时需填写' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: secretController,
                    decoration: InputDecoration(
                      labelText: 'App Secret',
                      prefixIcon: const Icon(Icons.password_outlined),
                      helperText: secretController.text.startsWith('****')
                          ? '已加密保存，留空保持不变'
                          : null,
                    ),
                    obscureText: true,
                    validator: (v) =>
                        enabled && (v?.isEmpty == true) ? '启用时需填写' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: verifyController,
                    decoration: InputDecoration(
                      labelText: 'Webhook Verify Token',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      helperText: verifyController.text.startsWith('****')
                          ? '已加密保存，留空保持不变'
                          : null,
                    ),
                    obscureText: true,
                    validator: (v) => enabled && ((v?.length ?? 0) < 8)
                        ? '至少 8 位'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: versionController,
                    decoration: const InputDecoration(
                      labelText: 'API 版本',
                      prefixIcon: Icon(Icons.api_outlined),
                    ),
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

                final businessId = businessIdController.text.trim();
                final displayPhone = displayPhoneController.text.trim();

                final success = await ref
                    .read(adminSitesProvider.notifier)
                    .updateSite(site.id, {
                  'whatsappConfig': {
                    'enabled': enabled,
                    'phoneNumberId': phoneIdController.text.trim(),
                    if (businessId.isNotEmpty) 'businessAccountId': businessId,
                    if (displayPhone.isNotEmpty)
                      'displayPhoneNumber': displayPhone,
                    'accessToken': tokenController.text,
                    'appSecret': secretController.text,
                    'verifyToken': verifyController.text,
                    'apiVersion': versionController.text.trim(),
                  },
                });

                if (!context.mounted) return;
                Navigator.pop(context);
                _showResultSnackBar(success, '配置已保存');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultSnackBar(bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? message : '操作失败，请重试'),
        backgroundColor: success ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }
}
