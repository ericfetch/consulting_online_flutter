import 'dart:async';
import 'package:consulting_online_app/core/network/dio_client.dart';
import 'package:consulting_online_app/data/models/copilot.dart';
import 'package:consulting_online_app/data/models/group.dart';
import 'package:consulting_online_app/data/models/user.dart';
import 'package:consulting_online_app/data/repositories/admin_repository.dart';
import 'package:consulting_online_app/data/repositories/agent_repository.dart';
import 'package:consulting_online_app/data/repositories/customer_repository.dart';
import 'package:consulting_online_app/features/admin/pages/dashboard_page.dart';
import 'package:consulting_online_app/features/admin/providers/admin_providers.dart';
import 'package:consulting_online_app/features/agent/providers/agent_availability.dart';
import 'package:consulting_online_app/features/agent/providers/agent_providers.dart';
import 'package:consulting_online_app/features/agent/widgets/copilot_panel.dart';
import 'package:consulting_online_app/features/agent/widgets/message_bubble.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'copilot_test.dart' as fixture;

AgentUser user(String status, String? time, {String id = 'u1'}) =>
    AgentUser.fromJson({
      'id': id,
      'name': '客服',
      'role': 'ADMIN',
      'agentStatus': status,
      'updatedAt': time
    });
const recent = '2026-09-29T05:00:00Z', old = '2026-09-29T04:00:00Z';

class StatusRepository extends fixture.FakeRepository {
  final updates = <Map<String, dynamic>>[];
  final waits = <Completer<AgentUser>>[];
  @override
  Future<AgentUser> updateSettings(Map<String, dynamic> data) {
    updates.add(data);
    final done = Completer<AgentUser>();
    waits.add(done);
    return done.future;
  }
}

class DashboardRepository extends AdminRepository {
  int reads = 0;
  bool fail = false;
  Completer<DashboardStats>? pending;
  DashboardRepository() : super(DioClient());
  @override
  Future<DashboardStats> getDashboard() async {
    reads++;
    if (fail) throw Exception('temporary network failure');
    if (pending != null) return pending!.future;
    return DashboardStats.fromJson({
      'agents': 1,
      'activeConversationsToday': 16,
      'conversationsToday': 14,
      'messagesToday': 85,
      'summarizedCustomers': 4,
      'summarizedCustomersToday': 2,
      'timezone': 'Asia/Shanghai',
      'generatedAt': recent,
      'agentRoster': [
        {'id': 'u1', 'name': 'eric', 'role': 'ADMIN', 'agentStatus': 'OFFLINE'}
      ],
      'trend': [
        {
          'date': '2026-09-29',
          'conversations': 14,
          'consultations': 16,
          'messages': 85
        }
      ]
    });
  }
}

class DownloadDio extends DioClient {
  String? requestedPath;
  @override
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters, Options? options}) async {
    requestedPath = path;
    return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: '%PDF-synthetic'.codeUnits as T);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'older refresh and missing timestamps preserve the newer manual offline choice',
      () {
    final current = user('OFFLINE', recent);
    expect(latestAgentAvailability(current, user('ONLINE', old)).agentStatus,
        AgentStatus.offline);
    expect(latestAgentAvailability(current, user('ONLINE', null)).agentStatus,
        AgentStatus.offline);
    expect(
        latestAgentAvailability(current, user('BUSY', '2026-09-29T06:00:00Z'))
            .agentStatus,
        AgentStatus.busy);
    expect(
        latestAgentAvailability(current, user('ONLINE', old, id: 'other'))
            .agentStatus,
        AgentStatus.online);
    expect(AgentUser.fromJson(current.toJson()).updatedAt, current.updatedAt);
  });
  test(
      'manual status writes are serialized and never update locally before confirmation',
      () async {
    final repo = StatusRepository();
    final ws = fixture.RecordingWs();
    final provider = StateNotifierProvider<AgentAppNotifier, AgentAppState>(
        (ref) => AgentAppNotifier(repo, ws, ref, active: false));
    final container = ProviderContainer();
    final notifier = container.read(provider.notifier);
    final first = notifier.updateStatus(AgentStatus.busy);
    final last = notifier.updateStatus(AgentStatus.offline);
    await Future<void>.delayed(Duration.zero);
    expect(repo.updates, [
      {'agentStatus': 'BUSY'}
    ]);
    expect(notifier.state.settings, isNull);
    repo.waits[0].complete(user('BUSY', old));
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(repo.updates.last, {'agentStatus': 'OFFLINE'});
    repo.waits[1].complete(user('OFFLINE', recent));
    await last;
    expect(notifier.state.settings?.agentStatus, AgentStatus.offline);
    container.dispose();
    ws.dispose();
  });
  test(
      'media, per-message translations and summary purposes survive snapshot parsing',
      () {
    final data = CopilotSnapshot.fromJson({
      'enabled': true,
      'autoSuggest': true,
      'asrEnabled': true,
      'visionEnabled': true,
      'translations': [
        {
          'messageId': 'm1',
          'status': 'COMPLETED',
          'text': '你好',
          'sourceLanguage': 'en'
        }
      ],
      'recognitions': [
        {
          'messageId': 'm2',
          'attachmentIndex': 1,
          'kind': 'audio',
          'status': 'COMPLETED',
          'text': 'Hello',
          'translatedText': '你好'
        }
      ],
      'runs': [
        {
          'id': 'r',
          'purpose': 'summary',
          'sourceMessageId': 'm2',
          'createdAt': recent,
          'status': 'COMPLETED',
          'events': []
        }
      ]
    });
    expect(data.translations.single.messageId, 'm1');
    expect(data.recognitions.single.attachmentIndex, 1);
    expect(data.recognitions.single.translatedText, '你好');
    expect(data.runs.single.purpose, 'summary');
  });
  test(
      'doctor PDF export excludes notes unless explicitly requested and rejects external download paths',
      () async {
    final dio = DownloadDio();
    final repo = CustomerRepository(dio);
    expect(await repo.exportPdf('record'), isNotEmpty);
    expect(dio.requestedPath,
        '/api/customers/record/export.pdf?includeNotes=false');
    await repo.exportPdf('record', includeNotes: true);
    expect(dio.requestedPath, endsWith('includeNotes=true'));
    await expectLater(
        repo.download('https://untrusted.invalid/report'), throwsException);
  });
  test(
      'dashboard does not overlap requests or turn existing values into zeros on failure',
      () async {
    final repo = DashboardRepository();
    final notifier = DashboardNotifier(repo);
    final pending = Completer<DashboardStats>();
    repo.pending = pending;
    final first = notifier.loadStats();
    await notifier.loadStats();
    expect(repo.reads, 1);
    pending.complete(const DashboardStats(summarizedCustomers: 4));
    await first;
    repo.pending = null;
    repo.fail = true;
    await notifier.loadStats();
    expect(notifier.state.stats?.summarizedCustomers, 4);
    expect(notifier.state.error, isNotNull);
    notifier.dispose();
  });
  testWidgets(
      'reply content and Chinese appear below their own message anchor, without a title',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = fixture.FakeRepository();
    await tester.pumpWidget(ProviderScope(
        overrides: [agentRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: Column(children: [
          CopilotPanel(
              conversationId: 'c1',
              sourceMessageId: 'm1',
              onChoose: (_, __) {}),
          CopilotPanel(
              conversationId: 'c1',
              sourceMessageId: 'm2',
              onChoose: (_, __) {}),
        ]))))));
    await tester.pumpAndSettle();
    expect(find.text('Please share your report.'), findsOneWidget);
    expect(find.text('请提供报告'), findsOneWidget);
    expect(find.text('补充资料'), findsNothing);
    expect(find.text('已生成回复方案'), findsOneWidget);
    expect(find.text('分析并生成回复'), findsOneWidget);
    await tester.tap(find.byTooltip('收起助手'));
    await tester.pumpAndSettle();
    expect(find.text('Please share your report.'), findsNothing);
    await tester.tap(find.byTooltip('展开助手'));
    await tester.pumpAndSettle();
    expect(find.text('Please share your report.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('one-tap copy uses original customer text', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'];
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MessageBubble(
                message: fixture.message(),
                showAvatar: true,
                conversation: fixture.conversation))));
    await tester.tap(find.byTooltip('一键复制'));
    await tester.pump();
    expect(copied, 'Original message');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'dashboard refreshes every five seconds, pauses when hidden and uses new metrics on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = DashboardRepository();
    final container = ProviderContainer(
        overrides: [adminRepositoryProvider.overrideWithValue(repo)]);
    Widget page(bool visible) => UncontrolledProviderScope(
        container: container,
        child:
            MaterialApp(home: Scaffold(body: DashboardPage(visible: visible))));
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(find.text('已汇总客户'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    final reads = repo.reads;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(repo.reads, reads + 1);
    await tester.pumpWidget(page(false));
    await tester.pump(const Duration(seconds: 10));
    expect(repo.reads, reads + 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
