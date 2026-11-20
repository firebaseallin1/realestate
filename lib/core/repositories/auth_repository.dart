import '../../models/app_user.dart';
import '../api/api_client.dart';

/// Signing in and out. Failures throw an ApiException with a message to show.
abstract class AuthRepository {
  Future<AppUser> login(String username, String password);

  /// The user of a saved sign-in, or null if there is none to resume.
  Future<AppUser?> restoreSession();

  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  @override
  Future<AppUser> login(String username, String password) async {
    final session = await _api.post(
      '/auth/login',
      body: {'username': username.trim(), 'password': password},
      authenticated: false,
    );
    await _api.saveSession(session!);
    return AppUser.fromJson(session['user'] as Map<String, dynamic>);
  }

  @override
  Future<AppUser?> restoreSession() async {
    final session = await _api.restoreSession();
    return session == null ? null : AppUser.fromJson(session['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> logout() => _api.endSession();
}
