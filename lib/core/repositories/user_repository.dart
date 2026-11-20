import '../../models/app_user.dart';
import '../api/api_client.dart';

/// The team's accounts. Failures throw an ApiException with a message to show.
abstract class UserRepository {
  Future<List<AppUser>> fetchUsers();
  Future<AppUser> createUser(NewUser user);
  Future<AppUser> updateUser(String id, UserChanges changes);
  Future<void> removeUser(String id);
}

class ApiUserRepository implements UserRepository {
  ApiUserRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  /// More than this team will have; the API's largest page.
  static const _pageSize = '200';

  final ApiClient _api;

  @override
  Future<List<AppUser>> fetchUsers() async {
    final page = await _api.get('/users', query: {'limit': _pageSize});
    return [for (final json in page!['items'] as List<dynamic>) AppUser.fromJson(json as Map<String, dynamic>)];
  }

  @override
  Future<AppUser> createUser(NewUser user) async {
    final json = await _api.post('/users', body: user.toJson());
    return AppUser.fromJson(json!);
  }

  @override
  Future<AppUser> updateUser(String id, UserChanges changes) async {
    final json = await _api.patch('/users/$id', body: changes.toJson());
    return AppUser.fromJson(json!);
  }

  @override
  Future<void> removeUser(String id) async {
    await _api.delete('/users/$id');
  }
}
