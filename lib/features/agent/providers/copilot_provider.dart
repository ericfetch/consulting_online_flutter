import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/copilot.dart';
import '../../../data/repositories/agent_repository.dart';
import '../../../core/network/ws_client.dart' show generateRequestId;

class CopilotState {
  final CopilotSnapshot? snapshot;
  final bool requesting;
  final String? error;
  const CopilotState({this.snapshot, this.requesting = false, this.error});
}

class CopilotNotifier extends StateNotifier<CopilotState>
    with WidgetsBindingObserver {
  final AgentRepository repository;
  final String conversationId;
  Timer? _timer;
  bool _loading = false, _reload = false, _paused = false;
  int _readVersion = 0;
  String? _fromMessageId;
  String? lastRequestedRunId;

  void setMessageRange(String? firstId) {
    if (_fromMessageId == firstId) return;
    _fromMessageId = firstId;
    _readVersion++;
    refresh();
  }

  CopilotNotifier(this.repository, this.conversationId)
      : super(const CopilotState()) {
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(refresh);
  }

  Future<void> refresh() async {
    if (!mounted || _paused) return;
    _timer?.cancel();
    if (_loading) {
      _reload = true;
      return;
    }
    _loading = true;
    final version = ++_readVersion;
    var delay = const Duration(seconds: 4);
    try {
      final snapshot = await repository.getCopilot(conversationId,
          fromMessageId: _fromMessageId);
      if (!mounted || version != _readVersion) return;
      state = CopilotState(snapshot: snapshot, requesting: state.requesting);
      delay = Duration(
          seconds: snapshot.runs.any((run) => run.running) ||
                  snapshot.translations
                      .any((t) => ['PENDING', 'RUNNING'].contains(t.status)) ||
                  snapshot.recognitions.any((r) => r.running)
              ? 1
              : snapshot.enabled
                  ? 4
                  : 15);
    } catch (error) {
      if (!mounted || version != _readVersion) return;
      state = CopilotState(
          snapshot: error is CopilotAccessException ? null : state.snapshot,
          requesting: state.requesting,
          error: _error(error));
      delay = const Duration(seconds: 10);
    } finally {
      _loading = false;
      if (mounted && !_paused) {
        if (_reload) {
          _reload = false;
          _timer = Timer(Duration.zero, refresh);
        } else {
          _timer = Timer(delay, refresh);
        }
      }
    }
  }

  Future<bool> ask(String prompt,
      {String? sourceMessageId, String purpose = 'assist'}) async {
    if (state.requesting) return false;
    final question = copilotQuestion(prompt);
    if (question.isEmpty || question.length > 6000) {
      state = CopilotState(
          snapshot: state.snapshot,
          error: question.isEmpty ? '请输入要向助手咨询的问题' : '问题过长，请控制在 6000 字以内');
      return false;
    }
    state = CopilotState(snapshot: state.snapshot, requesting: true);
    try {
      final created = await repository.askCopilot(
          conversationId, prompt, generateRequestId(),
          sourceMessageId: sourceMessageId, purpose: purpose);
      if (!mounted) return false;
      lastRequestedRunId = created.id;
      state = CopilotState(snapshot: state.snapshot);
      await refresh();
      return true;
    } catch (error) {
      if (mounted) {
        state = CopilotState(snapshot: state.snapshot, error: _error(error));
      }
      return false;
    }
  }

  Future<void> stop(String runId) async {
    try {
      await repository.cancelCopilot(conversationId, runId);
      await refresh();
    } catch (error) {
      if (mounted) {
        state = CopilotState(snapshot: state.snapshot, error: _error(error));
      }
    }
  }

  Future<bool> canAdopt(CopilotRun run) async {
    final version = ++_readVersion;
    try {
      final snapshot = await repository.getCopilot(conversationId,
          fromMessageId: _fromMessageId ?? run.sourceMessageId);
      if (!mounted || version != _readVersion) return false;
      final current =
          snapshot.runs.where((item) => item.id == run.id).firstOrNull;
      final valid = snapshot.enabled && current != null && current.completed;
      state = CopilotState(
          snapshot: snapshot,
          requesting: state.requesting,
          error: valid ? null : '助手已关闭或这条记录不可用');
      return valid;
    } catch (error) {
      if (mounted && version == _readVersion) {
        state = CopilotState(
            snapshot: error is CopilotAccessException ? null : state.snapshot,
            requesting: state.requesting,
            error: _error(error));
      }
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (_paused) {
      _timer?.cancel();
    } else {
      refresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _error(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

final copilotProvider = StateNotifierProvider.autoDispose
    .family<CopilotNotifier, CopilotState, String>(
        (ref, id) => CopilotNotifier(ref.watch(agentRepositoryProvider), id));
