import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/customer_repository.dart';
import '../agent/providers/agent_providers.dart';
import '../auth/providers/auth_providers.dart';

class CustomerStatusNotifier extends StateNotifier<Map<String, dynamic>>
    with WidgetsBindingObserver {
  final CustomerRepository repository;
  final Ref ref;
  Timer? _timer;
  bool _loading = false;
  CustomerStatusNotifier(this.repository, this.ref) : super({}) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
    Future.microtask(refresh);
  }
  Future<void> refresh() async {
    if (!mounted ||
        _loading ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
      return;
    }
    final ids = ref
        .read(agentAppProvider)
        .assignedConversations
        .map((c) => c.id)
        .toList();
    if (ids.isEmpty) {
      state = {};
      return;
    }
    _loading = true;
    try {
      final data = await repository.statuses(ids);
      if (mounted) state = data;
    } catch (_) {
      /* Keep the last known badges through transient disconnects. */
    } finally {
      _loading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final customerStatusesProvider = StateNotifierProvider.autoDispose<
    CustomerStatusNotifier, Map<String, dynamic>>((ref) {
  ref.watch(authProvider.select((s) => s.user?.id));
  final notifier =
      CustomerStatusNotifier(ref.watch(customerRepositoryProvider), ref);
  ref.listen(agentAppProvider.select((s) => s.conversations),
      (_, __) => notifier.refresh());
  return notifier;
});
