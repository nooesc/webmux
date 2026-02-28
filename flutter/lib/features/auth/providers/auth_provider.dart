import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAuthState {
  final bool isAuthenticated;
  final String? error;

  const AppAuthState({this.isAuthenticated = false, this.error});

  AppAuthState copyWith({bool? isAuthenticated, String? error}) {
    return AppAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AppAuthState> {
  final SharedPreferences _prefs;
  static const _keyAuthenticated = 'is_authenticated';
  static const _keyPassword = 'app_password';

  AuthNotifier(this._prefs) : super(const AppAuthState()) {
    _init();
  }

  void _init() {
    final isAuth = _prefs.getBool(_keyAuthenticated) ?? false;
    state = state.copyWith(isAuthenticated: isAuth);
  }

  Future<void> setPassword(String password) async {
    await _prefs.setString(_keyPassword, password);
  }

  Future<bool> checkPassword(String password) async {
    final storedPassword = _prefs.getString(_keyPassword);
    if (storedPassword == null) {
      await _prefs.setString(_keyPassword, password);
      await _prefs.setBool(_keyAuthenticated, true);
      state = state.copyWith(isAuthenticated: true, error: null);
      return true;
    }
    return password == storedPassword;
  }

  Future<void> signIn(String password) async {
    state = state.copyWith(error: null);

    final isValid = await checkPassword(password);
    if (isValid) {
      await _prefs.setBool(_keyAuthenticated, true);
      state = state.copyWith(isAuthenticated: true, error: null);
    } else {
      state = state.copyWith(isAuthenticated: false, error: 'Invalid password');
    }
  }

  Future<void> signOut() async {
    await _prefs.setBool(_keyAuthenticated, false);
    state = state.copyWith(isAuthenticated: false, error: null);
  }

  bool get hasPassword => _prefs.getString(_keyPassword) != null;
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized before use');
});

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(prefs);
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAuthenticated;
});
