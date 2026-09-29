import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/message.dart';

String attachmentUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return '';
  if (uri.scheme == 'https' || uri.scheme == 'http') return uri.toString();
  if (value.startsWith('/api/uploads/') || value.startsWith('/uploads/')) {
    return Uri.parse(AppConstants.apiBaseUrl).resolve(value).toString();
  }
  return '';
}

Future<void> openMessageUrl(BuildContext context, String url) async {
  final target = attachmentUrl(url);
  try {
    if (target.isNotEmpty &&
        await launchUrl(Uri.parse(target),
            mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {/* Show an actionable error rather than dropping the tap. */}
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('暂时无法打开，请稍后重试')));
  }
}

class MessageAttachmentView extends StatelessWidget {
  final MessageAttachment attachment;
  const MessageAttachmentView({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    final url = attachmentUrl(attachment.url);
    if (attachment.type == 'image' || attachment.type == 'sticker') {
      final sticker = attachment.type == 'sticker';
      return GestureDetector(
        onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog.fullscreen(
                child: Scaffold(
                    appBar: AppBar(title: Text(sticker ? '贴纸' : '图片')),
                    body: Center(
                        child: InteractiveViewer(
                            minScale: .5,
                            maxScale: 5,
                            child: CachedNetworkImage(
                                imageUrl: url,
                                errorWidget: (_, __, ___) =>
                                    const Text('图片暂时无法加载'))))))),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              width: sticker ? 120 : 200,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox(
                  width: 120,
                  height: 100,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorWidget: (_, __, ___) => const SizedBox(
                  width: 120,
                  height: 80,
                  child: Center(child: Icon(Icons.broken_image_outlined))),
            )),
      );
    }
    if (attachment.type == 'audio') return MessageAudioPlayer(url: url);
    final video = attachment.type == 'video';
    final size = attachment.size;
    return InkWell(
      onTap: () => openMessageUrl(context, url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                video ? Icons.play_circle_outline : Icons.description_outlined),
            const SizedBox(width: 8),
            Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      attachment.filename?.isNotEmpty == true
                          ? attachment.filename!
                          : video
                              ? '打开视频'
                              : '打开文件',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  if (size != null)
                    Text(
                        size >= 1048576
                            ? '${(size / 1048576).toStringAsFixed(1)} MB'
                            : '${(size / 1024).ceil()} KB',
                        style: const TextStyle(fontSize: 11)),
                ])),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, size: 16),
          ])),
    );
  }
}

class MessageAudioPlayer extends StatefulWidget {
  final String url;
  const MessageAudioPlayer({super.key, required this.url});
  @override
  State<MessageAudioPlayer> createState() => _MessageAudioPlayerState();
}

class _MessageAudioPlayerState extends State<MessageAudioPlayer> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _state;
  StreamSubscription<Duration>? _position;
  bool _playing = false;
  bool _busy = false;
  bool _error = false;
  Duration _elapsed = Duration.zero;
  @override
  void dispose() {
    _state?.cancel();
    _position?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      if (_player == null) {
        _player = AudioPlayer();
        _state = _player!.onPlayerStateChanged.listen((state) {
          if (mounted) setState(() => _playing = state == PlayerState.playing);
        });
        _position = _player!.onPositionChanged.listen((position) {
          if (mounted) setState(() => _elapsed = position);
        });
      }
      if (_playing) {
        await _player!.pause();
      } else if (_player!.state == PlayerState.paused) {
        await _player!.resume();
      } else {
        await _player!.play(UrlSource(widget.url));
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 230,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
              tooltip: _playing ? '暂停语音' : '播放语音',
              onPressed: _busy ? null : _toggle,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_playing
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline)),
          const Expanded(child: Text('语音 / 音频')),
          Text(
              '${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12)),
        ]),
        if (_error)
          const Text('当前格式无法播放，可用其他应用打开', style: TextStyle(fontSize: 11)),
        TextButton(
            onPressed: () => openMessageUrl(context, widget.url),
            child: const Text('打开音频', style: TextStyle(fontSize: 11))),
      ]));
}
