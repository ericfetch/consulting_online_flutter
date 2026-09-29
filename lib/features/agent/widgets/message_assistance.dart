import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/message.dart';
import '../../../data/repositories/agent_repository.dart';
import '../providers/copilot_provider.dart';

/// Private translation and media results always belong to their original message.
class MessageAssistance extends ConsumerStatefulWidget {
  final ChatMessage message;
  const MessageAssistance({super.key, required this.message});
  @override
  ConsumerState<MessageAssistance> createState() => _MessageAssistanceState();
}

class _MessageAssistanceState extends ConsumerState<MessageAssistance> {
  final Set<String> _busy = {};
  String? _error;
  Future<void> _request(
      String key, Future<void> Function(AgentRepository) action) async {
    if (_busy.contains(key)) return;
    setState(() {
      _busy.add(key);
      _error = null;
    });
    try {
      await action(ref.read(agentRepositoryProvider));
      if (mounted) {
        await ref
            .read(copilotProvider(widget.message.conversationId).notifier)
            .refresh();
      }
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final snapshot = ref.watch(copilotProvider(m.conversationId)).snapshot;
    final translation =
        snapshot?.translations.where((t) => t.messageId == m.id).firstOrNull;
    final attachments = m.metadata?.attachments ?? [];
    final media = m.metadata?.whatsappMedia;
    final colors = Theme.of(context).colorScheme;
    final children = <Widget>[];
    if (media?.id?.isNotEmpty == true &&
        !media!.pending &&
        (media.error != null || attachments.isEmpty)) {
      children.add(TextButton.icon(
          onPressed: _busy.contains('attachment')
              ? null
              : () => _request('attachment',
                  (r) => r.retryAttachment(m.conversationId, m.id)),
          icon: const Icon(Icons.refresh, size: 15),
          label: Text(_busy.contains('attachment') ? '正在重新接收…' : '重试接收附件')));
    }
    if (m.senderType == MessageSenderType.visitor &&
        snapshot?.enabled == true &&
        translation != null) {
      if (translation.status == 'COMPLETED' &&
          !translation.sourceLanguage.toLowerCase().startsWith('zh') &&
          translation.text != m.translatedContent) {
        children.add(_text('中文 · ${translation.text}'));
      } else if (translation.status == 'FAILED') {
        children.add(TextButton(
            onPressed: _busy.contains('translation')
                ? null
                : () => _request('translation',
                    (r) => r.translateMessage(m.conversationId, m.id)),
            child: const Text('翻译未完成，重试')));
      } else if (['RUNNING', 'PENDING'].contains(translation.status)) {
        children.add(_text('Think · 正在翻译…'));
      }
    }
    for (var i = 0; i < attachments.length; i++) {
      final attachment = attachments[i];
      if (attachment.type != 'audio' && attachment.type != 'image') continue;
      final index = i;
      final result = snapshot?.recognitions
          .where((r) => r.messageId == m.id && r.attachmentIndex == index)
          .firstOrNull;
      final audio = attachment.type == 'audio';
      final enabled = snapshot?.enabled == true &&
          (audio ? snapshot!.asrEnabled : snapshot!.visionEnabled);
      final busy = _busy.contains('media-$i') || result?.running == true;
      if (audio || result?.status == 'FAILED') {
        if (result?.status != 'COMPLETED') {
          children.add(TextButton.icon(
              onPressed: !enabled || busy
                  ? null
                  : () => _request('media-$index',
                      (r) => r.recognizeMessage(m.conversationId, m.id, index)),
              icon: Icon(audio ? Icons.transcribe_outlined : Icons.image_search,
                  size: 15),
              label: Text(busy
                  ? 'Think · 识别中…'
                  : !enabled
                      ? '识别模型未启用'
                      : result?.status == 'FAILED'
                          ? '重试识别'
                          : '语音识别')));
        }
      }
      if (!audio && enabled && (result == null || busy)) {
        children.add(_text('Think · 正在识别图片…'));
      }
      if (result != null) {
        if (audio && result.text.isNotEmpty) {
          children.add(SelectableText(result.text,
              style: const TextStyle(fontSize: 12, height: 1.5)));
        }
        if (result.status == 'COMPLETED') {
          if (audio &&
              result.translatedText.isNotEmpty &&
              result.translatedText != result.text) {
            children.add(_text('中文 · ${result.translatedText}'));
          }
          if (!audio) {
            children.add(_text('图片识别 · ${result.summary}'));
            if (result.text.isNotEmpty) {
              children.add(ExpansionTile(
                  dense: true,
                  tilePadding: EdgeInsets.zero,
                  title: const Text('查看识别文字', style: TextStyle(fontSize: 12)),
                  children: [SelectableText(result.text)]));
            }
          }
        }
        if (result.status == 'FAILED') {
          children.add(Text(result.error,
              style: TextStyle(fontSize: 11, color: colors.error)));
        }
      }
    }
    if (_error != null) {
      children.add(
          Text(_error!, style: TextStyle(fontSize: 12, color: colors.error)));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.fromLTRB(44, 3, 8, 6),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children));
  }

  Widget _text(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText(text,
          style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant)));
}
