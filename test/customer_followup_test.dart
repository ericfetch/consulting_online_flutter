import 'dart:async';
import 'package:consulting_online_app/core/network/dio_client.dart';
import 'package:consulting_online_app/data/models/customer_followup.dart';
import 'package:consulting_online_app/data/repositories/customer_repository.dart';
import 'package:consulting_online_app/features/customers/customer_followup_panel.dart';
import 'package:consulting_online_app/features/customers/customer_pages.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> snapshot(
        {String stage = 'WAIT_NOTIFY',
        int version = 0,
        List<Map<String, dynamic>> jobs = const [],
        List<Map<String, dynamic>> events = const [],
        int? total}) =>
    {
      'stage': stage,
      'version': version,
      'owner': {'id': 'eric', 'name': 'Eric'},
      'notifyEnabled': true,
      'notifiedAt': stage == 'WAIT_NOTIFY' ? null : '2026-09-29T08:00:00Z',
      'events': events,
      'total': total ?? events.length,
      'page': 1,
      'notifications': jobs,
    };
Map<String, dynamic> job(String status) => {
      'id': 'job-1',
      'status': status,
      'detail': '通知状态',
      'actorName': 'Eric',
      'createdAt': '2026-09-29T08:00:00Z',
      'expiresAt': '2099-01-01T00:00:00Z'
    };

class FollowupRepo extends CustomerRepository {
  FollowupRepo() : super(DioClient());
  Map<String, dynamic> data = snapshot();
  int reads = 0, notifications = 0;
  List<int> pages = [];
  List<Map<String, dynamic>> changes = [], filters = [];
  List<String> notificationIds = [], revoked = [];
  bool failChange = false, conflict = false, failNotify = false;
  Completer<FollowupNotification>? pendingNotify;
  @override
  Future<List<FollowupOwner>> followupOwners() async => const [
        FollowupOwner(id: 'eric', name: 'Eric'),
        FollowupOwner(id: 'ally', name: 'Ally')
      ];
  @override
  Future<CustomerFollowupData> followup(String id, {int page = 1}) async {
    reads++;
    pages.add(page);
    return CustomerFollowupData.fromJson({...data, 'page': page});
  }

  @override
  Future<CustomerFollowupData> changeFollowup(
      String id, Map<String, dynamic> input) async {
    changes.add(Map.from(input));
    if (conflict) {
      data = snapshot(stage: 'CONFIRMING', version: 2);
      throw Exception('跟踪进度已被更新');
    }
    if (failChange) throw Exception('网络异常');
    data = {
      ...data,
      'version': (data['version'] as int) + 1,
      if (input['stage'] != null) 'stage': input['stage']
    };
    return CustomerFollowupData.fromJson(data);
  }

  @override
  Future<FollowupNotification> notifyCustomer(String id,
      {required String requestId, required bool supplement}) async {
    notifications++;
    notificationIds.add(requestId);
    if (failNotify) throw Exception('网络异常');
    data = {
      ...data,
      'notifications': [job('PENDING')]
    };
    if (pendingNotify != null) return pendingNotify!.future;
    return FollowupNotification.fromJson(job('PENDING'));
  }

  @override
  Future<CustomerFollowupData> revokeNotification(
      String id, String jobId) async {
    revoked.add(jobId);
    data = {
      ...data,
      'notifications': [
        {...job('SENT'), 'revokedAt': '2026-09-29T09:00:00Z'}
      ]
    };
    return CustomerFollowupData.fromJson(data);
  }

  @override
  Future<Map<String, dynamic>> list(
      {String search = '',
      int page = 1,
      String? followupStage,
      String? ownerId}) async {
    filters.add({
      'search': search,
      'page': page,
      'followupStage': followupStage,
      'ownerId': ownerId
    });
    return {
      'items': [
        {
          'id': 'customer',
          'name': 'Example',
          'country': 'Canada',
          'condition': 'Example',
          'followupStage': 'WAIT_PAYMENT',
          'followupOwner': {'name': 'Eric'},
          'notifiedAt': '2026-09-29T08:00:00Z'
        }
      ],
      'total': 1
    };
  }
}

class CaptureDio extends DioClient {
  String? route;
  dynamic payload;
  int status = 200;
  dynamic result = snapshot();
  @override
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters, Options? options}) async {
    route = path;
    payload = queryParameters;
    return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
        data: result as T);
  }

  @override
  Future<Response<T>> post<T>(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Options? options}) async {
    route = path;
    payload = data;
    return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
        data: result as T);
  }
}

Future<void> mountPanel(WidgetTester tester, FollowupRepo repo,
    {bool unsaved = false}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
      overrides: [customerRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: CustomerFollowupPanel(
                      customerId: 'customer', unsaved: unsaved))))));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  test('twelve stages and request IDs match the backend contract', () {
    expect(followupStages.length, 12);
    final ids = List.generate(100, (_) => followupRequestId());
    expect(ids.toSet().length, 100);
    for (final id in ids) {
      expect(
          id,
          matches(RegExp(
              r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$')));
    }
  });
  test(
      'repository sends filters, versions and idempotency IDs to the existing followup endpoints',
      () async {
    final dio = CaptureDio();
    final api = CustomerRepository(dio);
    dio.result = {'items': [], 'total': 0};
    await api.list(followupStage: 'WAIT_PAYMENT', ownerId: 'eric', page: 2);
    expect(dio.payload, {
      'search': '',
      'page': 2,
      'followupStage': 'WAIT_PAYMENT',
      'ownerId': 'eric'
    });
    dio.result = snapshot(stage: 'MATCHING', version: 4);
    await api.changeFollowup('customer', {
      'requestId': 'key',
      'version': 3,
      'stage': 'MATCHING',
      'note': 'note'
    });
    expect(dio.route, '/api/customer-followup/customer/progress');
    expect(dio.payload['version'], 3);
    dio.result = job('PENDING');
    await api.notifyCustomer('customer', requestId: 'key', supplement: true);
    expect(dio.payload, {'requestId': 'key', 'supplement': true});
    dio.result = {'error': '跟踪进度已被更新'};
    dio.status = 409;
    await expectLater(api.changeFollowup('customer', {}),
        throwsA(predicate((e) => e.toString().contains('已被更新'))));
  });
  testWidgets(
      'notification does not advance the stage until the server confirms delivery, and double taps do not resend',
      (tester) async {
    final repo = FollowupRepo();
    repo.pendingNotify = Completer<FollowupNotification>();
    await mountPanel(tester, repo);
    await tester.tap(find.text('通知'));
    await tester.pump();
    await tester.tap(find.text('通知'));
    await tester.pump();
    expect(repo.notifications, 1);
    expect(find.text('待通知'), findsOneWidget);
    repo.pendingNotify!.complete(FollowupNotification.fromJson(job('PENDING')));
    await tester.pumpAndSettle();
    expect(find.text('等待处理'), findsOneWidget);
    expect(find.text('待匹配医生'), findsNothing);
    repo.data = snapshot(stage: 'MATCHING', version: 1, jobs: [job('SENT')]);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('待匹配医生'), findsOneWidget);
    expect(find.text('✓ 已通知'), findsOneWidget);
    expect(repo.notifications, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'notes survive polling and concurrent progress changes require an explicit rebase',
      (tester) async {
    final repo = FollowupRepo();
    repo.data = snapshot(stage: 'MATCHING', version: 1);
    await mountPanel(tester, repo);
    await tap(tester, '加备注');
    await tester.enterText(
        find.byKey(const ValueKey('followup-note')), '医生确认中');
    repo.data = snapshot(stage: 'CONFIRMING', version: 2);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('医生确认中'), findsOneWidget);
    expect(find.text('按最新进度继续'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存跟进'))
            .onPressed,
        isNull);
    await tap(tester, '按最新进度继续');
    await tap(tester, '保存跟进');
    expect(repo.changes.single['version'], 2);
    expect(repo.changes.single['note'], '医生确认中');
    expect(repo.changes.single.containsKey('stage'), false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'progress save retries reuse request IDs and preserve draft after an HTTP conflict',
      (tester) async {
    final repo = FollowupRepo();
    repo.data = snapshot(stage: 'MATCHING', version: 1);
    repo.failChange = true;
    await mountPanel(tester, repo);
    await tap(tester, '更新进度');
    await tester.enterText(
        find.byKey(const ValueKey('followup-note')), '已联系医生');
    await tap(tester, '保存跟进');
    await tap(tester, '保存跟进');
    expect(repo.changes.length, 2);
    expect(repo.changes[0]['requestId'], repo.changes[1]['requestId']);
    repo.conflict = true;
    await tap(tester, '保存跟进');
    expect(find.text('已联系医生'), findsOneWidget);
    expect(find.text('按最新进度继续'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'unsaved records disable notifications and waiting-notify cannot manually advance',
      (tester) async {
    final repo = FollowupRepo();
    await mountPanel(tester, repo, unsaved: true);
    expect(
        tester
            .widget<FilledButton>(find
                .ancestor(
                    of: find.text('通知'),
                    matching: find
                        .byWidgetPredicate((widget) => widget is FilledButton))
                .first)
            .onPressed,
        isNull);
    await tap(tester, '更新进度');
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>).first)
            .onChanged,
        isNull);
    expect(find.text('通知成功后，自动进入待匹配医生。'), findsOneWidget);
    expect(repo.notifications, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'uncertain notification requires checking the group and network retries keep the same request',
      (tester) async {
    final repo = FollowupRepo();
    repo.data = snapshot(jobs: [job('UNCERTAIN')]);
    repo.failNotify = true;
    await mountPanel(tester, repo);
    await tap(tester, '核对后重新通知');
    expect(repo.notifications, 0);
    await tap(tester, '已核对，重新通知');
    expect(repo.notifications, 1);
    await tap(tester, '核对后重新通知');
    await tap(tester, '已核对，重新通知');
    expect(repo.notificationIds[0], repo.notificationIds[1]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('background polling pauses and resumes without losing notes',
      (tester) async {
    final repo = FollowupRepo();
    await mountPanel(tester, repo);
    await tap(tester, '加备注');
    await tester.enterText(find.byKey(const ValueKey('followup-note')), '保留草稿');
    final reads = repo.reads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(repo.reads, reads);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.reads, reads + 1);
    expect(find.text('保留草稿'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'notification history exposes explicit revoke with server confirmation',
      (tester) async {
    final repo = FollowupRepo();
    repo.data = snapshot(stage: 'MATCHING', jobs: [job('SENT')]);
    await mountPanel(tester, repo);
    await tap(tester, '通知记录');
    await tap(tester, '撤销链接');
    expect(repo.revoked, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, '撤销链接'));
    await tester.pumpAndSettle();
    expect(repo.revoked, ['job-1']);
    expect(find.text('PDF 链接已撤销'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'customer list shows stages and owners and filters the server query',
      (tester) async {
    final repo = FollowupRepo();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
        overrides: [customerRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: CustomerListPage())));
    await tester.pumpAndSettle();
    expect(find.text('待支付在线问诊费用 · 已通知'), findsOneWidget);
    expect(find.text('负责人：Eric'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('待匹配医生').last);
    await tester.pumpAndSettle();
    expect(repo.filters.last['followupStage'], 'MATCHING');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
