import 'package:consulting_online_app/core/network/dio_client.dart';
import 'package:consulting_online_app/core/network/ws_client.dart';
import 'package:consulting_online_app/core/utils/date_utils.dart';
import 'package:consulting_online_app/data/models/conversation.dart';
import 'package:consulting_online_app/data/models/copilot.dart';
import 'package:consulting_online_app/data/models/message.dart';
import 'package:consulting_online_app/data/models/user.dart';
import 'package:consulting_online_app/data/repositories/agent_repository.dart';
import 'package:consulting_online_app/features/agent/pages/chat_page.dart';
import 'package:consulting_online_app/features/agent/providers/agent_providers.dart';
import 'package:consulting_online_app/features/agent/providers/copilot_provider.dart';
import 'package:consulting_online_app/features/agent/widgets/copilot_panel.dart';
import 'package:consulting_online_app/features/agent/widgets/message_bubble.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sentAt = DateTime.utc(2026, 9, 28, 6, 30);
final conversation = Conversation(
    id: 'c1',
    status: 'OPEN',
    visitorName: '客户',
    lastMessageAt: sentAt,
    createdAt: sentAt);
ChatMessage message(
        {MessageSenderType sender = MessageSenderType.visitor,
        DeliveryStatus? delivery}) =>
    ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      senderType: sender,
      body: 'Original message',
      createdAt: sentAt,
      deliveryStatus: delivery,
      metadata: const MessageMetadata(
          translation: MessageTranslation(detectedLanguage: 'en', text: '消息译文'),
          originalText: '发送前原文'),
    );
final run = CopilotRun.fromJson({
  'id': 'r1',
  'trigger': 'manual',
  'prompt': '给我回复建议',
  'status': 'COMPLETED',
  'sourceMessageId': 'm1',
  'events': [
    {
      'id': 'e1',
      'kind': 'card',
      'at': sentAt.toIso8601String(),
      'card': {
        'kind': 'replies',
        'options': [
          {
            'id': 'A',
            'label': '补充资料',
            'staffText': '请提供报告',
            'customerText': 'Please share your report.',
            'customerLanguage': 'en'
          }
        ]
      }
    }
  ],
});
CopilotSnapshot snapshot({String latest = 'm1'}) => CopilotSnapshot(
    enabled: true, autoSuggest: true, latestMessageId: latest, runs: [run]);

class FakeRepository extends AgentRepository {
  FakeRepository() : super(DioClient());
  CopilotSnapshot current = snapshot();
  bool deny = false;
  final asks = <String>[];
  int reads = 0;
  @override
  Future<CopilotSnapshot> getCopilot(String conversationId,
      {String? fromMessageId}) async {
    reads++;
    if (deny) throw CopilotAccessException('无权访问');
    return current;
  }

  @override
  Future<CopilotRun> askCopilot(
      String conversationId, String prompt, String requestId,
      {String? sourceMessageId, String purpose = 'assist'}) async {
    asks.add(prompt);
    return run;
  }

  @override
  Future<AgentUser> getSettings() async =>
      throw Exception('No network in tests');
}

class RecordingDio extends DioClient {
  String? path;
  dynamic body;
  int status = 200;
  @override
  Future<Response<T>> post<T>(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Options? options}) async {
    this.path = path;
    body = data;
    return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
        data: (status == 200 ? {'id': 'r1', 'events': []} : {'error': '无权访问'})
            as T);
  }
}

class RecordingWs extends WsClient {
  final publicMessages = <String>[];
  @override
  void connect({String? cookie}) {}
  @override
  bool sendMessage(String conversationId, String body,
      {Map<String, dynamic>? metadata, String? requestId}) {
    publicMessages.add(body);
    return true;
  }
}

class SeededAgent extends AgentAppNotifier {
  SeededAgent(super.repo, super.ws, super.ref, {bool closed = false}) {
    state = AgentAppState(
      presenceClock: DateTime.now(),
      connected: true,
      selectedId: 'c1',
      messages: [message()],
      conversations: [
        closed
            ? Conversation(
                id: 'c1',
                status: 'OPEN',
                channel: ConversationChannel.whatsapp,
                whatsappWindowExpiresAt: sentAt,
                lastMessageAt: sentAt,
                createdAt: sentAt)
            : conversation
      ],
      settings: const AgentUser(
          id: 'u1', name: '客服', email: '', role: UserRole.admin),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'mentions recognize Chinese punctuation without treating normal text as an internal request',
      () {
    for (final text in ['@agent 帮我翻译', ' @AGENT：解释病名', '@agent帮我看报告']) {
      expect(isCopilotMention(text), true);
    }
    expect(copilotQuestion(' @AGENT：解释病名'), '解释病名');
    expect(isCopilotMention('@agents hello'), false);
    expect(isCopilotMention('联系 @agent'), false);
  });
  test('AI replies stay real messages and round-trip their sender type', () {
    final ai = ChatMessage.fromJson({
      'id': 'm1',
      'senderType': 'AI',
      'createdAt': sentAt.toIso8601String()
    });
    expect(ai.isSystem, false);
    expect(ai.isFromAi, true);
    expect(ai.toJson()['senderType'], 'AI');
  });
  test(
      'private request uses scoped API, strips mention, and rejects HTTP permission errors',
      () async {
    final dio = RecordingDio();
    final repository = AgentRepository(dio);
    await repository.askCopilot('c1', '@agent：解释病名', 'request-123');
    expect(dio.path, '/api/agent/conversations/c1/copilot');
    expect(dio.body,
        {'prompt': '解释病名', 'requestId': 'request-123', 'purpose': 'assist'});
    dio.status = 403;
    await expectLater(
        repository.askCopilot('c1', 'test', 'request-456'), throwsException);
  });
  test('lost access clears previously displayed internal history', () async {
    final repository = FakeRepository();
    final notifier = CopilotNotifier(repository, 'c1');
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.snapshot?.runs.length, 1);
    repository.deny = true;
    await notifier.refresh();
    expect(notifier.state.snapshot, isNull);
    expect(notifier.state.error, '无权访问');
    notifier.dispose();
  });

  for (final scenario in [
    ('visitor', MessageSenderType.visitor, DeliveryStatus.sent),
    ('pending', MessageSenderType.agent, DeliveryStatus.pending),
    ('failed', MessageSenderType.agent, DeliveryStatus.failed),
    ('system', MessageSenderType.system, DeliveryStatus.sent),
    ('AI', MessageSenderType.ai, DeliveryStatus.sent),
  ]) {
    testWidgets('${scenario.$1} message always shows local sent time',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MessageBubble(
                  message: message(sender: scenario.$2, delivery: scenario.$3),
                  showAvatar: true,
                  conversation: conversation))));
      expect(find.text(AppDateUtils.formatDateTime(sentAt)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'long press copies message, translation and original text, including system messages',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MessageBubble(
                message: message(sender: MessageSenderType.system),
                showAvatar: true,
                conversation: conversation))));
    for (final entry in {
      '复制消息': 'Original message',
      '复制译文': '消息译文',
      '复制原文': '发送前原文'
    }.entries) {
      await tester.longPress(find.text('Original message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(copied, entry.value);
    }
  });

  for (final outdated in [false, true]) {
    testWidgets(
        'reply adoption still works after new messages (outdated=$outdated)',
        (tester) async {
      final repository = FakeRepository();
      CopilotReply? adopted;
      await tester.pumpWidget(ProviderScope(
          overrides: [agentRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
              home: Scaffold(
                  body: CopilotPanel(
                      conversationId: 'c1',
                      latestMessageId: 'm1',
                      onChoose: (reply, source) => adopted = reply)))));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('copilot-reply-r1-A'));
      await tester.ensureVisible(button);
      if (outdated) repository.current = snapshot(latest: 'm2');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(adopted?.customerText, 'Please share your report.');
      expect(repository.reads, greaterThanOrEqualTo(2));
      expect(repository.asks, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  testWidgets(
      'Think keeps previous replies usable and publishes new results only on completion',
      (tester) async {
    final repository = FakeRepository();
    CopilotRun next(String status) => CopilotRun(
            id: 'r2',
            trigger: 'manual',
            prompt: '下一轮',
            status: status,
            sourceMessageId: 'm2',
            events: [
              const CopilotEvent(
                  id: 'thinking', kind: 'status', text: '正在生成回复'),
              ...run.events
            ]);
    repository.current = CopilotSnapshot(
        enabled: true,
        autoSuggest: true,
        latestMessageId: 'm2',
        runs: [run, next('RUNNING')]);
    CopilotReply? adopted;
    await tester.pumpWidget(ProviderScope(
        overrides: [agentRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
            home: Scaffold(
                body: CopilotPanel(
                    conversationId: 'c1',
                    latestMessageId: 'm2',
                    onChoose: (reply, source) => adopted = reply)))));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(CopilotPanel)));
    expect(find.text('Think · 正在生成回复'), findsOneWidget);
    expect(find.byKey(const ValueKey('copilot-reply-r2-A')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('copilot-reply-r1-A')));
    await tester.pumpAndSettle();
    expect(adopted?.customerText, 'Please share your report.');
    repository.current = CopilotSnapshot(
        enabled: true,
        autoSuggest: true,
        latestMessageId: 'm2',
        runs: [run, next('COMPLETED')]);
    await container.read(copilotProvider('c1').notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.textContaining('Think ·'), findsNothing);
    expect(find.byKey(const ValueKey('copilot-reply-r1-A')), findsOneWidget);
    expect(find.byKey(const ValueKey('copilot-reply-r2-A')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
      '@agent uses only private HTTP even with a closed WhatsApp window; choosing a reply only fills draft',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final repository = FakeRepository();
    final ws = RecordingWs();
    await tester.pumpWidget(ProviderScope(overrides: [
      agentRepositoryProvider.overrideWithValue(repository),
      agentAppProvider.overrideWith(
          (ref) => SeededAgent(repository, ws, ref, closed: true)),
    ], child: const MaterialApp(home: ChatPage(conversationId: 'c1'))));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('AI 助手在线'), findsOneWidget);
    final composer = find.widgetWithText(TextField, '可输入 @agent 内部求助');
    await tester.enterText(composer, '@agent 帮我翻译');
    await tester.pump();
    await tester.tap(find.byTooltip('向内部助手提问'));
    await tester.pumpAndSettle();
    expect(repository.asks, ['@agent 帮我翻译']);
    expect(ws.publicMessages, isEmpty);
    final choose = find.byKey(const ValueKey('copilot-reply-r1-A'));
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(composer);
    expect(field.controller!.text, 'Please share your report.');
    expect(ws.publicMessages, isEmpty);
    expect(find.textContaining('中文参考'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    ws.dispose();
  });
}
