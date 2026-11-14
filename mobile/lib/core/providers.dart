import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';
import '../data/models.dart';

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

/// Index of the visible bottom-navigation tab, shared so in-page actions
/// (for example "Review breached") can switch tabs.
final shellTabProvider = StateProvider<int>((ref) => 0);

class AuthState {
  const AuthState({
    this.booting = true,
    this.user,
    this.token,
    this.error,
    this.busy = false,
  });

  final bool booting;
  final User? user;
  final String? token;
  final String? error;
  final bool busy;

  bool get isAuthenticated => user != null && token != null;

  AuthState copyWith({
    bool? booting,
    User? user,
    String? token,
    String? error,
    bool? busy,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        booting: booting ?? this.booting,
        user: clearUser ? null : (user ?? this.user),
        token: clearUser ? null : (token ?? this.token),
        error: clearError ? null : (error ?? this.error),
        busy: busy ?? this.busy,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api) : super(const AuthState());

  final ApiClient _api;
  static const _kToken = 'civicai.access_token';
  static const _kRefresh = 'civicai.refresh_token';
  static const _kUser = 'civicai.user';

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final rawUser = prefs.getString(_kUser);
    if (token == null || rawUser == null) {
      state = const AuthState(booting: false);
      return;
    }

    _api.setToken(token);
    User? cached;
    try {
      cached = User.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
    } catch (_) {
      cached = null;
    }
    state = AuthState(booting: false, token: token, user: cached);

    // Refresh the profile in the background; keep the cached session usable
    // when the device is offline.
    try {
      final fresh = await _api.me();
      _api.setToken(token);
      await _persist(token, prefs.getString(_kRefresh), fresh);
      state = AuthState(booting: false, token: token, user: fresh);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await signOut();
      }
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await _api.login(email, password);
      _api.setToken(result.token);
      final prefs = await SharedPreferences.getInstance();
      await _persist(result.token, result.refreshToken, result.user, prefs);
      state = AuthState(
        booting: false,
        token: result.token,
        user: result.user,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
    String? ward,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await _api.register(
        fullName: fullName,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        ward: ward,
      );
      _api.setToken(result.token);
      final prefs = await SharedPreferences.getInstance();
      await _persist(result.token, result.refreshToken, result.user, prefs);
      state = AuthState(
        booting: false,
        token: result.token,
        user: result.user,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
      return false;
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String? phoneNumber,
    required String? ward,
  }) async {
    final updated = await _api.updateProfile(
      fullName: fullName,
      phoneNumber: phoneNumber ?? '',
      ward: ward ?? '',
    );
    final prefs = await SharedPreferences.getInstance();
    await _persist(state.token, prefs.getString(_kRefresh), updated, prefs);
    state = state.copyWith(user: updated);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUser);
    _api.setToken(null);
    state = const AuthState(booting: false);
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> _persist(
    String? token,
    String? refreshToken,
    User user, [
    SharedPreferences? existing,
  ]) async {
    final prefs = existing ?? await SharedPreferences.getInstance();
    if (token != null) await prefs.setString(_kToken, token);
    if (refreshToken != null) await prefs.setString(_kRefresh, refreshToken);
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
  }
}

final authProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(apiProvider))..bootstrap();
});

final lookupsProvider = FutureProvider<Lookups>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    throw ApiException('Sign in to load municipal data.', statusCode: 401);
  }
  return ref.watch(apiProvider).lookups();
});

final analyticsProvider =
    FutureProvider.autoDispose.family<AnalyticsOverview, int>((ref, days) {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    throw ApiException('Sign in to load analytics.', statusCode: 401);
  }
  return ref.watch(apiProvider).analytics(days: days);
});

class ComplaintFilter {
  const ComplaintFilter({
    this.status,
    this.priority,
    this.search = '',
    this.overdue = false,
    this.assignedToMe = false,
  });

  final String? status;
  final String? priority;
  final String search;
  final bool overdue;
  final bool assignedToMe;

  bool get isActive =>
      status != null ||
      priority != null ||
      search.trim().isNotEmpty ||
      overdue ||
      assignedToMe;

  ComplaintFilter copyWith({
    String? status,
    String? priority,
    String? search,
    bool? overdue,
    bool? assignedToMe,
    bool clearStatus = false,
    bool clearPriority = false,
  }) =>
      ComplaintFilter(
        status: clearStatus ? null : (status ?? this.status),
        priority: clearPriority ? null : (priority ?? this.priority),
        search: search ?? this.search,
        overdue: overdue ?? this.overdue,
        assignedToMe: assignedToMe ?? this.assignedToMe,
      );
}

final complaintFilterProvider =
    StateProvider.autoDispose<ComplaintFilter>((ref) => const ComplaintFilter());

final complaintsProvider =
    FutureProvider.autoDispose<ComplaintPage>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    throw ApiException('Sign in to view complaints.', statusCode: 401);
  }
  final filter = ref.watch(complaintFilterProvider);
  return ref.watch(apiProvider).complaints(
        status: filter.status,
        priority: filter.priority,
        search: filter.search.trim().isEmpty ? null : filter.search.trim(),
        overdue: filter.overdue,
        assignedToMe: filter.assignedToMe,
        limit: 50,
      );
});

final complaintDetailProvider =
    FutureProvider.autoDispose.family<ComplaintDetail, int>((ref, id) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    throw ApiException('Sign in to view this complaint.', statusCode: 401);
  }
  return ref.watch(apiProvider).complaint(id);
});

final notificationsProvider =
    FutureProvider.autoDispose<NotificationFeed>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    throw ApiException('Sign in to view notifications.', statusCode: 401);
  }
  return ref.watch(apiProvider).notifications();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return 0;
  return ref.watch(apiProvider).unreadNotifications();
});

final hotspotsProvider = FutureProvider.autoDispose<HotspotFeed>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    throw ApiException('Sign in to load hotspots.', statusCode: 401);
  }
  return ref.watch(apiProvider).hotspots();
});
