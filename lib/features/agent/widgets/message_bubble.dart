import 'message_attachment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/agent_utils.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;
  final Conversation conversation;
  final bool isTranslating;
  final VoidCallback? onReply;
  final VoidCallback? onTranslate;

  const MessageBubble({
    super.key,
    required this.message,
    required this.showAvatar,
    required this.conversation,
    this.isTranslating = false,
    this.onReply,
    this.onTranslate,
  });

  bool get _isMe => message.isFromAgent || message.isFromAi;
  bool get _isSystem => message.isSystem;

  @override
  Widget build(BuildContext context) {
    if (_isSystem) {
      return _buildSystemMessage(context);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final displayName = visitorDisplayName(conversation);

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment:
              _isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!_isMe) ...[
              _buildAvatar(context, displayName),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    _isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showAvatar && !_isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: message.isImage
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                    decoration: BoxDecoration(
                      color: _isMe
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(_isMe ? 20 : 4),
                        bottomRight: Radius.circular(_isMe ? 4 : 20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMessageContent(context),
                        if (message.translatedContent != null)
                          _buildTranslation(context),
                        if (isTranslating)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: _isMe
                                        ? Colors.white70
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Think · 翻译中…',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isMe
                                        ? Colors.white70
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppDateUtils.formatDateTime(message.createdAt),
                          style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant),
                        ),
                        _copyButton(context),
                        if (message.isPending || message.isFailed)
                          const SizedBox(width: 6),
                        if (message.isPending)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        else if (message.isFailed)
                          GestureDetector(
                            onTap: onReply,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 14,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  message.clientError ?? '发送失败',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isMe) ...[
              const SizedBox(width: 8),
              _buildMyAvatar(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String displayName) {
    if (!showAvatar) {
      return const SizedBox(width: 36);
    }

    if (conversation.visitorAvatarUrl.isNotEmpty) {
      return UserAvatar(
        name: displayName,
        imageUrl: conversation.visitorAvatarUrl,
        size: 36,
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          conversation.visitorInitial,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildMyAvatar(BuildContext context) {
    if (!showAvatar) {
      return const SizedBox(width: 36);
    }

    if (message.senderAvatarUrl.isNotEmpty) {
      return UserAvatar(
        name: message.senderName,
        imageUrl: message.senderAvatarUrl,
        size: 36,
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          message.senderName.isNotEmpty ? message.senderName[0] : '我',
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final meta = message.metadata;
    final attachments = meta?.attachments ?? const <MessageAttachment>[];
    final textColor =
        _isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final bodyIsAttachment = attachments.any((a) =>
        a.url == message.body ||
        attachmentUrl(a.url) == attachmentUrl(message.body) &&
            attachmentUrl(message.body).isNotEmpty);
    return DefaultTextStyle.merge(
        style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
        child: IconTheme.merge(
            data: IconThemeData(color: textColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meta?.whatsappForwarded == true)
                  const Text('已转发', style: TextStyle(fontSize: 11)),
                if (meta?.whatsappQuotedMessage != null)
                  Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(
                                  color: textColor.withValues(alpha: .4),
                                  width: 2))),
                      child: Text(meta!.whatsappQuotedMessage!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))),
                for (final attachment in attachments)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: MessageAttachmentView(
                          key: ValueKey(attachment.url),
                          attachment: attachment)),
                if (!bodyIsAttachment && message.body.isNotEmpty)
                  Text(message.body),
                if (meta?.whatsappMedia?.pending == true)
                  const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('附件接收中…', style: TextStyle(fontSize: 12))),
                if (meta?.whatsappMedia?.error != null)
                  Text('附件接收失败：${meta!.whatsappMedia!.error}',
                      style: const TextStyle(fontSize: 12)),
                if (meta?.whatsappLocationUrl
                        ?.startsWith('https://www.google.com/maps/') ==
                    true)
                  TextButton(
                      onPressed: () =>
                          openMessageUrl(context, meta!.whatsappLocationUrl!),
                      child: const Text('在地图中查看')),
              ],
            )));
  }

  Widget _buildTranslation(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = _isMe ? Colors.white70 : colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: _isMe
                ? Colors.white24
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.translate,
                size: 12,
                color: textColor,
              ),
              const SizedBox(width: 4),
              Text(
                '翻译',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.translatedContent!,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(message.displayContent,
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(AppDateUtils.formatDateTime(message.createdAt),
                  style: TextStyle(
                      fontSize: 10, color: colorScheme.onSurfaceVariant)),
              _copyButton(context),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _copyButton(BuildContext context) => IconButton(
      tooltip: '一键复制',
      icon: const Icon(Icons.copy_outlined, size: 14),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(4),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(
            text: message.body.isNotEmpty
                ? message.body
                : message.imageUrls.join('\n')));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('已复制'), duration: Duration(seconds: 1)));
        }
      });

  Future<void> _showContextMenu(BuildContext context) async {
    final original = message.metadata?.originalText;
    final copyText =
        message.body.isNotEmpty ? message.body : message.imageUrls.join('\n');
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (copyText.isNotEmpty)
          ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制消息'),
              onTap: () => Navigator.pop(sheetContext, 'copy')),
        if (message.translatedContent?.isNotEmpty == true)
          ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('复制译文'),
              onTap: () => Navigator.pop(sheetContext, 'translation')),
        if (original != null && original.isNotEmpty && original != copyText)
          ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('复制原文'),
              onTap: () => Navigator.pop(sheetContext, 'original')),
        if (!_isSystem && onReply != null)
          ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('回复'),
              onTap: () => Navigator.pop(sheetContext, 'reply')),
        if (onTranslate != null &&
            message.isFromVisitor &&
            message.translatedContent == null &&
            !isTranslating)
          ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('翻译'),
              onTap: () => Navigator.pop(sheetContext, 'translate')),
      ])),
    );
    if (!context.mounted || action == null) return;
    if (action == 'reply') {
      onReply?.call();
      return;
    }
    if (action == 'translate') {
      onTranslate?.call();
      return;
    }
    final text = action == 'translation'
        ? message.translatedContent!
        : action == 'original'
            ? original!
            : copyText;
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
    }
  }
}
