import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/group.dart';
import '../../../data/models/site.dart';
import '../../../data/repositories/admin_repository.dart';

class DashboardState {
  final DashboardStats? stats;
  final bool isLoading;
  final String? error;

  const DashboardState({this.stats, this.isLoading = false, this.error});

  DashboardState copyWith({
    DashboardStats? stats,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final AdminRepository _repo;

  DashboardNotifier(this._repo) : super(const DashboardState());

  Future<void> loadStats() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final stats = await _repo.getDashboard();
      state = state.copyWith(stats: stats, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class AdminUsersState {
  final List<AdminUser> users;
  final bool isLoading;
  final String? error;

  const AdminUsersState({this.users = const [], this.isLoading = false, this.error});

  AdminUsersState copyWith({
    List<AdminUser>? users,
    bool? isLoading,
    String? error,
  }) {
    return AdminUsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminUsersNotifier extends StateNotifier<AdminUsersState> {
  final AdminRepository _repo;

  AdminUsersNotifier(this._repo) : super(const AdminUsersState());

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final users = await _repo.getUsers();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> createUser(Map<String, dynamic> data) async {
    try {
      final user = await _repo.createUser(data);
      state = state.copyWith(users: [...state.users, user]);
      return true;
    } catch (e) {
      return false;
    }
  }
}

class AdminGroupsState {
  final List<AgentGroup> groups;
  final bool isLoading;
  final String? error;

  const AdminGroupsState({this.groups = const [], this.isLoading = false, this.error});

  AdminGroupsState copyWith({
    List<AgentGroup>? groups,
    bool? isLoading,
    String? error,
  }) {
    return AdminGroupsState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminGroupsNotifier extends StateNotifier<AdminGroupsState> {
  final AdminRepository _repo;

  AdminGroupsNotifier(this._repo) : super(const AdminGroupsState());

  Future<void> loadGroups() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final groups = await _repo.getGroups();
      state = state.copyWith(groups: groups, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> createGroup(Map<String, dynamic> data) async {
    try {
      final group = await _repo.createGroup(data);
      state = state.copyWith(groups: [...state.groups, group]);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateGroup(String id, Map<String, dynamic> data) async {
    try {
      final group = await _repo.updateGroup(id, data);
      state = state.copyWith(
        groups: state.groups.map((g) => g.id == id ? group : g).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteGroup(String id) async {
    try {
      await _repo.deleteGroup(id);
      state = state.copyWith(
        groups: state.groups.where((g) => g.id != id).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

class AdminSitesState {
  final List<Site> sites;
  final bool isLoading;
  final String? error;

  const AdminSitesState({this.sites = const [], this.isLoading = false, this.error});

  AdminSitesState copyWith({
    List<Site>? sites,
    bool? isLoading,
    String? error,
  }) {
    return AdminSitesState(
      sites: sites ?? this.sites,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminSitesNotifier extends StateNotifier<AdminSitesState> {
  final AdminRepository _repo;

  AdminSitesNotifier(this._repo) : super(const AdminSitesState());

  Future<void> loadSites() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sites = await _repo.getSites();
      state = state.copyWith(sites: sites, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> createSite(Map<String, dynamic> data) async {
    try {
      final site = await _repo.createSite(data);
      state = state.copyWith(sites: [...state.sites, site]);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateSite(String id, Map<String, dynamic> data) async {
    try {
      final site = await _repo.updateSite(id, data);
      state = state.copyWith(
        sites: state.sites.map((s) => s.id == id ? site : s).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

class AdminConversationsState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;
  final String filter;

  const AdminConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
    this.filter = 'all',
  });

  AdminConversationsState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
    String? filter,
  }) {
    return AdminConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filter: filter ?? this.filter,
    );
  }
}

class AdminConversationsNotifier
    extends StateNotifier<AdminConversationsState> {
  final AdminRepository _repo;

  AdminConversationsNotifier(this._repo)
      : super(const AdminConversationsState());

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final conversations = await _repo.getConversations(
        startAt: _startAtForFilter(state.filter),
      );
      state = state.copyWith(conversations: conversations, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
    loadConversations();
  }

  DateTime? _startAtForFilter(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
        return now.subtract(const Duration(days: 30));
      case 'all':
      default:
        return null;
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return DashboardNotifier(repo);
});

final adminUsersProvider =
    StateNotifierProvider<AdminUsersNotifier, AdminUsersState>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return AdminUsersNotifier(repo);
});

final adminGroupsProvider =
    StateNotifierProvider<AdminGroupsNotifier, AdminGroupsState>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return AdminGroupsNotifier(repo);
});

final adminSitesProvider =
    StateNotifierProvider<AdminSitesNotifier, AdminSitesState>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return AdminSitesNotifier(repo);
});

final adminConversationsProvider =
    StateNotifierProvider<AdminConversationsNotifier, AdminConversationsState>((
  ref,
) {
  final repo = ref.watch(adminRepositoryProvider);
  return AdminConversationsNotifier(repo);
});
