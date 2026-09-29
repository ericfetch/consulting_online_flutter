import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/customer_followup.dart';
import '../../data/repositories/customer_repository.dart';

class CustomerFollowupPanel extends ConsumerStatefulWidget {
  final String customerId;
  final bool unsaved;
  const CustomerFollowupPanel(
      {super.key, required this.customerId, this.unsaved = false});
  @override
  ConsumerState<CustomerFollowupPanel> createState() =>
      _CustomerFollowupPanelState();
}

class _CustomerFollowupPanelState extends ConsumerState<CustomerFollowupPanel>
    with WidgetsBindingObserver {
  CustomerFollowupData? _data;
  List<FollowupOwner> _owners = [];
  final _note = TextEditingController();
  Timer? _timer;
  bool _busy = false, _loading = false, _expanded = false, _foreground = true;
  String? _error,
      _ownerError,
      _editing,
      _notifyRequest,
      _notifyBaseline,
      _changeRequest,
      _changeKey;
  String _stage = '', _ownerId = '';
  int _version = 0, _sequence = 0, _page = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      _load();
      _loadOwners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    ++_sequence;
    WidgetsBinding.instance.removeObserver(this);
    _note.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      if (!_busy) _load();
    } else {
      _timer?.cancel();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!mounted || !_foreground) return;
    _timer = Timer(
        Duration(seconds: _data?.activeNotification != null ? 3 : 15), () {
      if (mounted && !_busy && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _load();
      } else {
        _schedule();
      }
    });
  }

  Future<void> _load() async {
    if (!mounted || _loading || _busy) return;
    _loading = true;
    final sequence = ++_sequence;
    try {
      final data = await ref
          .read(customerRepositoryProvider)
          .followup(widget.customerId, page: _page);
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _data = data;
        // A fresh notification record confirms that a timed-out POST was accepted.
        if (_notifyRequest != null &&
            data.latest != null &&
            data.latest!.id != _notifyBaseline) {
          _notifyRequest = null;
        }
      });
    } catch (error) {
      if (mounted && sequence == _sequence) {
        setState(() => _error = error.toString());
      }
    } finally {
      _loading = false;
      _schedule();
    }
  }

  Future<void> _loadOwners() async {
    try {
      final owners =
          await ref.read(customerRepositoryProvider).followupOwners();
      if (mounted) {
        setState(() {
          _owners = owners;
          _ownerError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _ownerError = '负责人列表读取失败');
    }
  }

  void _edit(String mode) {
    final data = _data;
    if (data == null || _busy) return;
    setState(() {
      _editing = mode;
      _version = data.version;
      _stage = data.stage;
      _ownerId = data.owner?.id ?? '';
      _note.clear();
      _error = null;
      _changeRequest = null;
      _changeKey = null;
    });
  }

  void _useLatest() {
    setState(() {
      _version = _data!.version;
      _stage = _data!.stage;
      _ownerId = _data!.owner?.id ?? '';
      _error = null;
      _changeRequest = null;
      _changeKey = null;
    });
  }

  Future<void> _save() async {
    if (_data == null || _busy || _version != _data!.version) return;
    final note = _note.text.trim();
    final stages = followupStages.keys.toList();
    if (_editing == 'progress' &&
        _stage != _data!.stage &&
        stages.indexOf(_stage) != stages.indexOf(_data!.stage) + 1 &&
        note.isEmpty) {
      setState(() => _error = '退回、跳转或提前完结时，请填写原因');
      return;
    }
    final input = <String, dynamic>{
      'version': _version,
      'note': note,
      if (_editing == 'progress') 'stage': _stage,
      if (_editing == 'progress' && _ownerId != (_data!.owner?.id ?? ''))
        'ownerId': _ownerId.isEmpty ? null : _ownerId,
    };
    final key = jsonEncode(input);
    if (key != _changeKey) {
      _changeKey = key;
      _changeRequest = followupRequestId();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    ++_sequence;
    try {
      final data = await ref.read(customerRepositoryProvider).changeFollowup(
          widget.customerId, {...input, 'requestId': _changeRequest});
      if (!mounted) return;
      setState(() {
        _data = data;
        _page = 1;
        _editing = null;
        _note.clear();
        _changeRequest = null;
        _changeKey = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(title),
                content: Text(body),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(action)),
                ],
              )) ??
      false;
  Future<void> _notify() async {
    final data = _data;
    if (data == null ||
        _busy ||
        widget.unsaved ||
        !data.notifyEnabled ||
        data.activeNotification != null) {
      return;
    }
    if (data.latest?.status == 'UNCERTAIN' &&
        !await _confirm(
            '核对通知结果', '上次发送结果未确认。请先检查飞书群，确认需要再次发送后继续。', '已核对，重新通知')) {
      return;
    }
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    ++_sequence;
    _notifyBaseline = data.latest?.id;
    _notifyRequest ??= followupRequestId();
    try {
      final job = await ref.read(customerRepositoryProvider).notifyCustomer(
          widget.customerId,
          requestId: _notifyRequest!,
          supplement: data.notifiedAt != null);
      if (!mounted) return;
      setState(() {
        _data!.notifications.removeWhere((item) => item.id == job.id);
        _data!.notifications.insert(0, job);
        _notifyRequest = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<void> _revoke(FollowupNotification job) async {
    if (_busy ||
        !await _confirm(
            '撤销 PDF 链接', '飞书中这次通知的 PDF 链接将无法打开，客户档案与其他通知不受影响。', '撤销链接')) {
      return;
    }
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    ++_sequence;
    try {
      final data = await ref
          .read(customerRepositoryProvider)
          .revokeNotification(widget.customerId, job.id);
      if (mounted) {
        setState(() {
          _data = data;
          _page = 1;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _schedule();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data, colors = Theme.of(context).colorScheme;
    final active = data?.activeNotification;
    final latest = data?.latest;
    final outdated =
        _editing != null && data != null && _version != data.version;
    final canSave = _editing == 'note'
        ? _note.text.trim().isNotEmpty
        : data != null &&
            (_stage != data.stage ||
                _ownerId != (data.owner?.id ?? '') ||
                _note.text.trim().isNotEmpty);
    final owners = [..._owners];
    if (data?.owner != null && !owners.any((o) => o.id == data!.owner!.id)) {
      owners.insert(0, data!.owner!);
    }
    final notifyLabel = active?.label ??
        (latest?.status == 'UNCERTAIN'
            ? '核对后重新通知'
            : latest?.status == 'FAILED'
                ? '重试通知'
                : data?.notifiedAt != null
                    ? '补充通知'
                    : '通知');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('客户跟踪',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (data != null)
                Text(followupStages[data.stage] ?? data.stage,
                    style: TextStyle(
                        color: colors.primary, fontWeight: FontWeight.w600)),
              if (data?.notifiedAt != null)
                const Text('✓ 已通知',
                    style: TextStyle(color: Colors.teal, fontSize: 12)),
            ]),
        const SizedBox(height: 8),
        Text(
            data == null
                ? '正在读取跟踪记录…'
                : '负责人：${data.owner?.name ?? '未指定'}${data.followedUpAt == null ? '' : '\n最近跟进 ${AppDateUtils.formatDateTime(data.followedUpAt)}'}',
            style: TextStyle(
                color: colors.onSurfaceVariant, fontSize: 12, height: 1.6)),
        if (_busy)
          const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator()),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, children: [
          OutlinedButton(
              onPressed: data == null || _busy ? null : () => _edit('note'),
              child: const Text('加备注')),
          OutlinedButton(
              onPressed: data == null || _busy ? null : () => _edit('progress'),
              child: const Text('更新进度')),
          FilledButton.icon(
              onPressed: data == null ||
                      !data.notifyEnabled ||
                      _busy ||
                      active != null ||
                      widget.unsaved
                  ? null
                  : _notify,
              icon: const Icon(Icons.send_outlined, size: 16),
              label: Text(notifyLabel)),
        ]),
        if (widget.unsaved)
          const Text('请先保存客户资料，再发送通知。', style: TextStyle(fontSize: 12)),
        if (data != null && !data.notifyEnabled)
          const Text('请先在后台配置客户资料通知群。', style: TextStyle(fontSize: 12)),
        if (_error != null)
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(_error!, style: TextStyle(color: colors.error)),
            TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _error = null);
                        _load();
                      },
                child: const Text('刷新'))
          ]),
        if (latest != null &&
            const ['FAILED', 'UNCERTAIN'].contains(latest.status))
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  '${latest.detail}${latest.status == 'UNCERTAIN' ? '，请先核对飞书群，避免重复发送。' : ''}',
                  style: TextStyle(color: colors.error, fontSize: 12))),
        if (_editing != null && data != null) ...[
          const Divider(height: 24),
          Row(children: [
            Expanded(
                child: Text(_editing == 'note' ? '添加跟进备注' : '更新跟踪进度',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            IconButton(
                tooltip: '取消编辑',
                onPressed: _busy ? null : () => setState(() => _editing = null),
                icon: const Icon(Icons.close, size: 18))
          ]),
          if (_editing == 'progress') ...[
            DropdownButtonFormField<String>(
                value: _stage,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '当前阶段'),
                items: followupStages.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        enabled: e.key != 'WAIT_NOTIFY' ||
                            data.stage == 'WAIT_NOTIFY',
                        child: Text(e.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: _busy || data.stage == 'WAIT_NOTIFY'
                    ? null
                    : (value) => setState(() => _stage = value!)),
            if (data.stage == 'WAIT_NOTIFY')
              const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child:
                      Text('通知成功后，自动进入待匹配医生。', style: TextStyle(fontSize: 12))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                value: _ownerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '负责客服'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('未指定')),
                  ...owners.map((o) => DropdownMenuItem(
                      value: o.id,
                      child: Text(o.name, overflow: TextOverflow.ellipsis)))
                ],
                onChanged: _busy || _ownerError != null
                    ? null
                    : (value) => setState(() => _ownerId = value!)),
            if (_ownerError != null)
              TextButton(
                  onPressed: _loadOwners, child: Text('$_ownerError，重试')),
            const SizedBox(height: 12),
          ],
          TextField(
              key: const ValueKey('followup-note'),
              controller: _note,
              enabled: !_busy,
              minLines: 3,
              maxLines: 6,
              maxLength: 5000,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: '跟进备注',
                  hintText: _editing == 'note'
                      ? '记录本次跟进情况'
                      : '记录医生、费用或预约进展；跳转或提前完结需填写原因')),
          if (outdated) ...[
            const Text('进度已被更新，备注草稿已保留。'),
            TextButton(
                onPressed: _busy ? null : _useLatest,
                child: const Text('按最新进度继续'))
          ],
          const Text('跟进备注仅内部可见，不进入医生 PDF。', style: TextStyle(fontSize: 12)),
          Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                  onPressed: _busy || outdated || !canSave ? null : _save,
                  child: const Text('保存跟进'))),
        ],
        if (data != null && data.events.isNotEmpty) ...[
          const Divider(height: 24),
          for (final event in _expanded ? data.events : data.events.take(3))
            Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          event['fromStage'] != event['toStage']
                              ? '${followupStages[event['fromStage']] ?? event['fromStage']} → ${followupStages[event['toStage']] ?? event['toStage']}'
                              : event['kind'] == 'NOTIFIED'
                                  ? '资料通知'
                                  : event['kind'] == 'REVOKED'
                                      ? '链接已撤销'
                                      : '跟进备注',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                          '${event['actorName'] ?? ''} · ${AppDateUtils.formatDateTime(DateTime.tryParse(event['createdAt'] ?? ''))}',
                          style: TextStyle(
                              fontSize: 11, color: colors.onSurfaceVariant)),
                      if ((event['note'] ?? '').isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: SelectableText(event['note'],
                                style: const TextStyle(
                                    fontSize: 13, height: 1.5))),
                    ])),
          if (data.total > 3)
            TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _expanded = !_expanded;
                          _page = 1;
                        });
                        _load();
                      },
                child: Text(_expanded ? '收起记录' : '查看全部 ${data.total} 条记录')),
          if (_expanded && data.total > 30)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  tooltip: '上一页记录',
                  onPressed: _page <= 1 || _busy || _loading
                      ? null
                      : () {
                          setState(() => _page--);
                          _load();
                        },
                  icon: const Icon(Icons.chevron_left)),
              Text('第 $_page 页'),
              IconButton(
                  tooltip: '下一页记录',
                  onPressed: _page * 30 >= data.total || _busy || _loading
                      ? null
                      : () {
                          setState(() => _page++);
                          _load();
                        },
                  icon: const Icon(Icons.chevron_right)),
            ]),
        ],
        if (data != null && data.notifications.isNotEmpty)
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('通知记录', style: TextStyle(fontSize: 13)),
              subtitle: const Text('最近 20 条', style: TextStyle(fontSize: 11)),
              children: [
                for (final job in data.notifications)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${job.label} · ${job.supplement ? '补充资料' : '客户资料'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(
                                '${job.actorName} · ${AppDateUtils.formatDateTime(job.createdAt)}',
                                style: const TextStyle(fontSize: 11)),
                            if (job.detail.isNotEmpty)
                              Text(job.detail,
                                  style: const TextStyle(fontSize: 12)),
                            if (job.expiresAt != null)
                              Text(
                                  job.revokedAt != null
                                      ? 'PDF 链接已撤销'
                                      : job.expiresAt!.isBefore(DateTime.now())
                                          ? 'PDF 链接已过期'
                                          : 'PDF 链接有效至 ${AppDateUtils.formatDateTime(job.expiresAt)}',
                                  style: const TextStyle(fontSize: 11)),
                            if (job.canRevoke)
                              TextButton(
                                  onPressed: _busy ? null : () => _revoke(job),
                                  child: const Text('撤销链接')),
                          ])),
              ]),
      ]),
    );
  }
}
