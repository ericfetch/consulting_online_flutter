import 'package:consulting_online_app/data/models/conversation.dart';
import 'package:consulting_online_app/data/models/message.dart';
import 'package:consulting_online_app/features/agent/widgets/message_attachment.dart';
import 'package:consulting_online_app/features/agent/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'file name, size, quoted reply and location survive local message serialization',
      () {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'conversationId': 'c1',
      'senderType': 'VISITOR',
      'createdAt': '2026-09-28T15:00:00Z',
      'body': '/api/uploads/file.pdf',
      'metadata': {
        'attachments': [
          {
            'type': 'document',
            'url': '/api/uploads/file.pdf',
            'filename': '检查报告.pdf',
            'size': 1024
          }
        ],
        'whatsappQuotedMessage': 'Original question',
        'whatsappForwarded': true,
        'whatsappLocationUrl':
            'https://www.google.com/maps/search/?api=1&query=0,0'
      }
    });
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.metadata!.attachments.single.filename, '检查报告.pdf');
    expect(restored.metadata!.attachments.single.size, 1024);
    expect(restored.metadata!.whatsappQuotedMessage, 'Original question');
    expect(restored.metadata!.whatsappForwarded, isTrue);
    expect(restored.metadata!.whatsappLocationUrl, contains('query=0,0'));
    expect(attachmentUrl('/api/uploads/file.pdf'),
        'https://consulting.sanain.com/api/uploads/file.pdf');
    expect(attachmentUrl('javascript:alert(1)'), isEmpty);
    expect(attachmentUrl('//example.test/private'), isEmpty);
  });

  for (final type in ['document', 'video', 'audio']) {
    testWidgets(
        '$type is actionable on a narrow phone and does not show raw attachment paths',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final at = DateTime.utc(2026, 9, 28);
      final message = ChatMessage(
          id: 'm1',
          conversationId: 'c1',
          senderType: MessageSenderType.visitor,
          createdAt: at,
          body: '/api/uploads/file',
          metadata: MessageMetadata(
              attachments: [
                MessageAttachment(
                    type: type,
                    url: '/api/uploads/file',
                    filename: type == 'document'
                        ? 'A very long report name from the customer - 检查报告.pdf'
                        : null,
                    size: 1024)
              ],
              whatsappQuotedMessage: 'Original question',
              whatsappForwarded: true));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MessageBubble(
                  message: message,
                  showAvatar: false,
                  conversation: Conversation(
                      id: 'c1',
                      status: 'OPEN',
                      lastMessageAt: at,
                      createdAt: at)))));
      expect(find.text('/api/uploads/file'), findsNothing);
      expect(find.text('Original question'), findsOneWidget);
      if (type == 'audio') {
        expect(find.byTooltip('播放语音'), findsOneWidget);
      } else {
        expect(find.byIcon(Icons.open_in_new), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending and failed attachments display their state',
      (tester) async {
    final at = DateTime.utc(2026, 9, 28);
    for (final pending in [true, false]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MessageBubble(
                  showAvatar: false,
                  conversation: Conversation(
                      id: 'c1',
                      status: 'OPEN',
                      lastMessageAt: at,
                      createdAt: at),
                  message: ChatMessage(
                      id: 'm1',
                      conversationId: 'c1',
                      senderType: MessageSenderType.visitor,
                      body: '文件：检查报告.pdf',
                      createdAt: at,
                      metadata: MessageMetadata(
                          whatsappMedia: MessageWhatsappMedia(
                              type: 'document',
                              pending: pending,
                              error: pending ? null : '媒体已过期')))))));
      expect(find.text(pending ? '附件接收中…' : '附件接收失败：媒体已过期'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
