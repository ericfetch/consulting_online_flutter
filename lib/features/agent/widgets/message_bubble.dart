import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

  bool get _isMe => message.isFromAgent;
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
                                    color: _isMe ? Colors.white70 : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '翻译中...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isMe ? Colors.white70 : colorScheme.onSurfaceVariant,
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
                          )
                        else
                          Text(
                            AppDateUtils.formatTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;

    if (message.isImage && message.imageUrls.isNotEmpty) {
      return _buildImages(context);
    }

    final textColor = _isMe ? Colors.white : colorScheme.onSurface;

    return Text(
      message.body,
      style: TextStyle(
        color: textColor,
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  Widget _buildImages(BuildContext context) {
    final urls = message.imageUrls;
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: urls.first,
          width: 200,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 200,
            height: 200,
            color: Colors.black12,
            child: const Center(child: LoadingIndicator(size: 24)),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 200,
            height: 200,
            color: Colors.black12,
            child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: urls.map((url) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: url,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 100,
              height: 100,
              color: Colors.black12,
              child: const Center(child: LoadingIndicator(size: 20)),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 100,
              height: 100,
              color: Colors.black12,
              child:
                  const Icon(Icons.broken_image, size: 32, color: Colors.grey),
            ),
          ),
        );
      }).toList(),
    );
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.displayContent,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final RenderObject? overlay =
        Overlay.of(context).context.findRenderObject();
    final RenderObject? renderObject = context.findRenderObject();

    if (renderObject is RenderBox && overlay is RenderBox) {
      final position =
          renderObject.localToGlobal(Offset.zero, ancestor: overlay);
      final size = renderObject.size;

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy + size.height,
          position.dx + size.width,
          position.dy,
        ),
        items: [
          if (onReply != null)
            PopupMenuItem(
              onTap: onReply,
              child: const ListTile(
                leading: Icon(Icons.reply),
                title: Text('回复'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (onTranslate != null &&
              message.isFromVisitor &&
              message.translatedContent == null &&
              !isTranslating)
            PopupMenuItem(
              onTap: onTranslate,
              child: const ListTile(
                leading: Icon(Icons.translate),
                title: Text('翻译'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      );
    }
  }
}
