import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/models/customer_followup.dart';
import '../../core/utils/date_utils.dart';
import 'customer_followup_panel.dart';
import 'customer_status_provider.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});
  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _page = 1, _total = 0, _generation = 0;
  String _stage = '', _ownerId = '';
  List<FollowupOwner> _owners = [];
  Timer? _timer;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_load);
    Future.microtask(() async {
      try {
        final owners =
            await ref.read(customerRepositoryProvider).followupOwners();
        if (mounted) setState(() => _owners = owners);
      } catch (_) {
        /* Listing remains available if owner options cannot load. */
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          _foreground &&
          !_loading &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        _load(page: _page, quiet: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && (ModalRoute.of(context)?.isCurrent ?? true)) {
      _load(page: _page, quiet: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1, bool quiet = false}) async {
    if (!mounted || (quiet && _loading)) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(customerRepositoryProvider).list(
          search: _search.text.trim(),
          page: page,
          followupStage: _stage,
          ownerId: _ownerId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = (data['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _total = data['total'] as int;
        _page = page;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('客户资料')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
                controller: _search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                    hintText: '搜索姓名、手机号、病种或国家',
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _load())))),
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              Expanded(
                  child: DropdownButtonFormField<String>(
                value: _stage,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '跟踪阶段'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('全部阶段')),
                  ...followupStages.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis)))
                ],
                onChanged: (value) {
                  setState(() => _stage = value!);
                  _load();
                },
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: DropdownButtonFormField<String>(
                value: _ownerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '负责客服'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('全部负责人')),
                  const DropdownMenuItem(
                      value: 'unassigned', child: Text('未指定')),
                  ..._owners.map((o) => DropdownMenuItem(
                      value: o.id,
                      child: Text(o.name, overflow: TextOverflow.ellipsis)))
                ],
                onChanged: (value) {
                  setState(() => _ownerId = value!);
                  _load();
                },
              )),
            ])),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          ListTile(
              title: Text(_error!),
              trailing: TextButton(
                  onPressed: () => _load(), child: const Text('重试'))),
        Expanded(
            child: RefreshIndicator(
                onRefresh: () => _load(page: _page),
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (!_loading && _items.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(child: Text('暂无客户资料'))),
                      for (final item in _items)
                        ListTile(
                            leading: const Icon(Icons.folder_shared_outlined),
                            title: Text(
                                (item['name'] as String?)?.isNotEmpty == true
                                    ? item['name']
                                    : '未填写姓名'),
                            subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text([
                                    item['country'],
                                    item['condition'],
                                    if (item['summarizedAt'] != null) '已汇总'
                                  ]
                                      .whereType<String>()
                                      .where((s) => s.isNotEmpty)
                                      .join(' · ')),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${followupStages[item['followupStage']] ?? '待通知'}${item['notifiedAt'] != null ? ' · 已通知' : ''}',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontSize: 12)),
                                  Text(
                                      '负责人：${item['followupOwner']?['name'] ?? '未指定'}${item['followedUpAt'] == null ? '' : '\n最近跟进 ${AppDateUtils.formatDateTime(DateTime.tryParse(item['followedUpAt']))}'}',
                                      style: const TextStyle(fontSize: 11)),
                                ]),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => CustomerDetailPage(
                                          customerId: item['id'])));
                              if (mounted) _load(page: _page);
                            }),
                    ]))),
        SafeArea(
            top: false,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  onPressed: !_loading && _page > 1
                      ? () => _load(page: _page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left)),
              Text('第 $_page 页 · 共 $_total 位'),
              IconButton(
                  onPressed: !_loading && _page * 30 < _total
                      ? () => _load(page: _page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right)),
            ])),
      ]));
}

class CustomerDetailPage extends ConsumerStatefulWidget {
  final String? customerId, conversationId;
  const CustomerDetailPage({super.key, this.customerId, this.conversationId});
  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  final _fields = {
    for (final key in ['name', 'country', 'age', 'condition', 'notes'])
      key: TextEditingController()
  };
  Map<String, dynamic>? _record;
  String _gender = '';
  bool _busy = false, _dirty = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(customerRepositoryProvider);
      final record = widget.customerId != null
          ? await repo.detail(widget.customerId!)
          : await repo.forConversation(widget.conversationId!);
      if (!mounted) return;
      for (final entry in _fields.entries) {
        entry.value.text = record[entry.key]?.toString() ?? '';
      }
      setState(() {
        _record = record;
        _gender = record['gender'] ?? '';
        _dirty = false;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _save() async {
    final ageText = _fields['age']!.text.trim();
    final age = int.tryParse(ageText);
    if (ageText.isNotEmpty && (age == null || age < 0 || age > 120)) {
      _notice('年龄请输入 0–120 的整数');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(customerRepositoryProvider).update(_record!['id'], {
        for (final key in ['name', 'country', 'condition', 'notes'])
          key: _fields[key]!.text.trim(),
        'age': age,
        'gender': _gender,
      });
      if (!mounted) return;
      await _load();
      _notice('客户资料已保存');
      if (mounted) ref.read(customerStatusesProvider.notifier).refresh();
    } catch (error) {
      _notice(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    var includeNotes = false;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('导出给医生'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('导出基本资料、沟通摘要、图片与报告。系统记录的 WhatsApp 联系号码不导出。'),
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includeNotes,
                        title: const Text('包含客服备注'),
                        onChanged: (value) => setDialogState(
                            () => includeNotes = value ?? false)),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('导出 PDF'))
                  ],
                )));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref
          .read(customerRepositoryProvider)
          .exportPdf(_record!['id'], includeNotes: includeNotes);
      if (!mounted) return;
      final saved = await FilePicker.platform.saveFile(
          dialogTitle: '保存患者资料',
          fileName: 'patient-record.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: bytes);
      if (saved != null) _notice('PDF 已保存');
    } catch (error) {
      _notice(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachment(Map<String, dynamic> file) async {
    setState(() => _busy = true);
    try {
      final bytes =
          await ref.read(customerRepositoryProvider).download(file['url']);
      if (!mounted) return;
      if ((file['mimeType'] as String? ?? '').startsWith('image/')) {
        await showDialog(
            context: context,
            builder: (context) => Dialog.fullscreen(
                child: Scaffold(
                    appBar: AppBar(title: Text(file['filename'] ?? '报告图片')),
                    body: Center(
                        child: InteractiveViewer(
                            maxScale: 5, child: Image.memory(bytes))))));
      } else {
        final name = (file['filename'] as String? ?? 'report.pdf')
            .split(RegExp(r'[/\\]'))
            .last;
        final path =
            await FilePicker.platform.saveFile(fileName: name, bytes: bytes);
        if (path != null) _notice('附件已保存');
      }
    } catch (error) {
      _notice(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('客户档案'), actions: [
        IconButton(
            tooltip: _dirty ? '请先保存修改再导出' : '导出 PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _record != null && !_busy && !_dirty ? _export : null)
      ]),
      body: _record == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: _load, child: Text('$_error\n点击重试')))
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_busy) const LinearProgressIndicator(),
              if ((_record!['whatsappPhone'] ?? '').toString().isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SelectableText(
                        'WhatsApp ${_record!['whatsappPhone']} · 仅内部',
                        style: const TextStyle(fontSize: 13))),
              CustomerFollowupPanel(
                  key: ValueKey(_record!['id']),
                  customerId: _record!['id'],
                  unsaved: _dirty),
              const SizedBox(height: 22),
              for (final entry in {
                'name': '姓名',
                'country': '国家 / 地区',
                'age': '年龄',
                'condition': '病种 / 主要问题'
              }.entries)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                        controller: _fields[entry.key],
                        enabled: !_busy,
                        keyboardType: entry.key == 'age'
                            ? TextInputType.number
                            : TextInputType.text,
                        maxLength: entry.key == 'condition'
                            ? 500
                            : entry.key == 'age'
                                ? 3
                                : 120,
                        decoration: InputDecoration(
                            labelText: entry.value, counterText: ''),
                        onChanged: (_) => setState(() => _dirty = true))),
              DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: '性别'),
                  items: const {
                    '': '未填写',
                    'female': '女',
                    'male': '男',
                    'other': '其他',
                    'prefer_not_to_say': '不便透露'
                  }
                      .entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                            _gender = value!;
                            _dirty = true;
                          })),
              const SizedBox(height: 22),
              const Text('沟通摘要', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SelectableText(
                  (_record!['summary'] as String?)?.isNotEmpty == true
                      ? _record!['summary']
                      : '尚未汇总。可在会话菜单中选择“汇总资料”。',
                  style: const TextStyle(height: 1.6)),
              const SizedBox(height: 22),
              const Text('报告附件', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final raw in _record!['files'] as List? ?? [])
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        (raw['mimeType'] as String? ?? '').startsWith('image/')
                            ? Icons.image_outlined
                            : Icons.description_outlined),
                    title: Text(raw['filename'] ?? '报告',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: _busy
                        ? null
                        : () => _attachment(Map<String, dynamic>.from(raw))),
              const SizedBox(height: 16),
              TextField(
                  controller: _fields['notes'],
                  maxLines: 4,
                  maxLength: 10000,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: '客服备注（默认不导出）'),
                  onChanged: (_) => setState(() => _dirty = true)),
              FilledButton(
                  onPressed: _dirty && !_busy ? _save : null,
                  child: const Text('保存资料')),
              const SizedBox(height: 20),
            ]));
}
