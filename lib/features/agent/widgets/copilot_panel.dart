import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/copilot.dart';
import '../providers/copilot_provider.dart';

/// Lives at a message anchor, inside the conversation's only scroll view.
class CopilotPanel extends ConsumerStatefulWidget {
  final String conversationId;
  final String? sourceMessageId;
  final String? latestMessageId;
  final void Function(CopilotReply, String?) onChoose;
  const CopilotPanel(
      {super.key,
      required this.conversationId,
      this.sourceMessageId,
      this.latestMessageId,
      required this.onChoose});
  @override
  ConsumerState<CopilotPanel> createState() => _CopilotPanelState();
}

class _CopilotPanelState extends ConsumerState<CopilotPanel> {
  bool _collapsed = false, _choosing = false;
  Future<void> _ask(
      [String prompt = replyPrompt, String purpose = 'assist']) async {
    setState(() => _collapsed = false);
    await ref.read(copilotProvider(widget.conversationId).notifier).ask(prompt,
        sourceMessageId: widget.sourceMessageId ?? widget.latestMessageId,
        purpose: purpose);
  }

  Future<void> _choose(CopilotRun run, CopilotReply reply) async {
    setState(() => _choosing = true);
    final allowed = await ref
        .read(copilotProvider(widget.conversationId).notifier)
        .canAdopt(run);
    if (!mounted) return;
    setState(() => _choosing = false);
    if (allowed) widget.onChoose(reply, run.sourceMessageId);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CopilotState>(copilotProvider(widget.conversationId),
        (before, after) {
      final known =
          before?.snapshot?.runs.map((r) => r.id).toSet() ?? <String>{};
      final hasNewRequest = after.snapshot?.runs.any((r) =>
              r.trigger == 'manual' &&
              !known.contains(r.id) &&
              r.sourceMessageId == widget.sourceMessageId) ==
          true;
      if (_collapsed && hasNewRequest) setState(() => _collapsed = false);
    });
    final state = ref.watch(copilotProvider(widget.conversationId));
    if (state.snapshot?.enabled != true) return const SizedBox.shrink();
    final runs = state.snapshot!.runs
        .where((r) =>
            widget.sourceMessageId == null ||
            r.sourceMessageId == widget.sourceMessageId)
        .toList();
    final hasReplies = runs.any((r) =>
        r.completed && r.events.any((e) => e.card?.options.isNotEmpty == true));
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.fromLTRB(10, 2, 8, 8),
      decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.primary.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.smart_toy_outlined,
                  size: 14, color: colors.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                  child: TextButton(
                      style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 4)),
                      onPressed: state.requesting ? null : () => _ask(),
                      child: Text(hasReplies ? '已生成回复方案' : '分析并生成回复',
                          style: const TextStyle(fontSize: 12)))),
              if (runs.isNotEmpty)
                IconButton(
                    tooltip: _collapsed ? '展开助手' : '收起助手',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                        _collapsed ? Icons.expand_more : Icons.expand_less,
                        size: 19),
                    onPressed: () => setState(() => _collapsed = !_collapsed)),
            ]),
            if (!_collapsed) ...[
              for (final run in runs) ...[
                Text(
                    '${run.purpose == 'summary' ? '资料汇总' : run.purpose == 'quick_reply' ? '快捷回复' : 'AI 助手'} · 仅内部 · ${AppDateUtils.formatTime(run.createdAt)}',
                    style: TextStyle(
                        fontSize: 10, color: colors.onSurfaceVariant)),
                if (run.running)
                  Row(children: [
                    Expanded(
                        child: Text('Think · ${run.progress}',
                            style: TextStyle(
                                fontSize: 12, color: colors.onSurfaceVariant))),
                    TextButton(
                        onPressed: () => ref
                            .read(
                                copilotProvider(widget.conversationId).notifier)
                            .stop(run.id),
                        child: const Text('停止')),
                  ])
                else if (run.completed)
                  _result(run)
                else
                  Row(children: [
                    Expanded(
                        child: Text(
                            run.status == 'CANCELLED'
                                ? '已停止'
                                : run.events
                                        .where((e) => e.kind == 'error')
                                        .lastOrNull
                                        ?.text ??
                                    '处理未完成',
                            style:
                                TextStyle(fontSize: 12, color: colors.error))),
                    TextButton(
                        onPressed: state.requesting
                            ? null
                            : () => _ask(run.prompt, run.purpose),
                        child: const Text('重试')),
                  ]),
              ],
            ],
          ]),
    );
  }

  Widget _result(CopilotRun run) {
    final cards = run.events
        .where((e) => e.card != null && e.card!.kind != 'sources')
        .map((e) => e.card!)
        .toList();
    final lastReplies = cards.where((c) => c.kind == 'replies').lastOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final card in cards)
        if (card.kind == 'replies') ...[
          if (card == lastReplies)
            for (final reply in card.options) _reply(run, reply),
        ] else if (card.kind == 'profile_saved')
          _text('已汇总到客户资料 · ${card.data['fileCount'] ?? 0} 份附件')
        else if (card.kind == 'translation')
          _text(card.text('translatedText'))
        else if (card.kind == 'intent' || card.kind == 'case') ...[
          _text(card.text('summary')),
          if (card.kind == 'case')
            for (final line in card.lines('nextSteps')) _text(line),
        ],
      if (cards.isEmpty)
        _text(
            run.events.where((e) => e.kind == 'answer').lastOrNull?.text ?? ''),
    ]);
  }

  Widget _reply(CopilotRun run, CopilotReply reply) {
    final colors = Theme.of(context).colorScheme;
    final rtl = RegExp(r'^(ar|he|fa|ur)(-|_|$)', caseSensitive: false)
        .hasMatch(reply.customerLanguage);
    return InkWell(
      key: ValueKey('copilot-reply-${run.id}-${reply.id}'),
      onTap: _choosing ? null : () => _choose(run, reply),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 23,
                height: 23,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(reply.id, style: const TextStyle(fontSize: 11))),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text(reply.customerText,
                      textDirection:
                          rtl ? TextDirection.rtl : TextDirection.ltr,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                  if (reply.staffText.trim().isNotEmpty &&
                      reply.staffText != reply.customerText &&
                      !reply.customerLanguage.toLowerCase().startsWith('zh'))
                    Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(reply.staffText,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: colors.onSurfaceVariant))),
                ])),
            const SizedBox(width: 6),
            Icon(Icons.north_west, size: 14, color: colors.onSurfaceVariant),
          ])),
    );
  }

  Widget _text(String value) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SelectableText(value,
              style: const TextStyle(fontSize: 12, height: 1.5)));
}

class CopilotPresence extends ConsumerWidget {
  final String conversationId;
  const CopilotPresence({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(copilotProvider(conversationId));
    final enabled = state.snapshot?.enabled;
    final online = enabled == true && state.error == null;
    final color =
        online ? Colors.teal : Theme.of(context).colorScheme.onSurfaceVariant;
    final label = state.error != null
        ? 'AI 助手暂不可用'
        : online
            ? 'AI 助手在线'
            : enabled == false
                ? 'AI 助手未启用'
                : 'AI 助手连接中';
    return Tooltip(
      message: '仅客服可见 · 在消息框输入 @agent 求助',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.smart_toy_outlined, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: color))),
      ]),
    );
  }
}
