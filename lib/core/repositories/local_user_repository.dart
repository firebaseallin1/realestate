import '../../models/app_user.dart';
import '../api/api_client.dart';
import 'auth_repository.dart';
import 'user_repository.dart';

/// LocalUserRepository is the in-memory stand-in for the backend, used by
/// tests. The app itself always signs in through the API, so these accounts
/// cannot be used to sign in to the real app.
class LocalUserRepository implements AuthRepository, UserRepository {
  static const String demoPassword = 'kaira123';

  final List<AppUser> accounts = [
    const AppUser(id: 'u1', name: 'Admin', username: 'admin', role: UserRole.admin, phone: '98480 11111'),
    const AppUser(
      id: 'u2',
      name: 'Priya Sharma',
      username: 'sales',
      role: UserRole.salesExecutive,
      phone: '98480 22222',
    ),
    const AppUser(id: 'u3', name: 'Ravi Kumar', username: 'manager', role: UserRole.siteManager, phone: '98480 33333'),
    const AppUser(
      id: 'u4',
      name: 'Suresh Reddy',
      username: 'incharge',
      role: UserRole.siteIncharge,
      phone: '98480 44444',
    ),
  ];
  final Map<String, String> _passwords = {
    'admin': demoPassword,
    'sales': demoPassword,
    'manager': demoPassword,
    'incharge': demoPassword,
  };
  int _nextId = 5;

  @override
  Future<AppUser> login(String username, String password) async {
    final key = username.trim().toLowerCase();
    if (_passwords[key] != password) {
      throw const ApiException('INVALID_CREDENTIALS', 'Incorrect username or password.', statusCode: 401);
    }
    return accounts.firstWhere((u) => u.username == key);
  }

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<List<AppUser>> fetchUsers() async => List.of(accounts);

  @override
  Future<AppUser> createUser(NewUser user) async {
    final key = user.username.toLowerCase();
    if (_passwords.containsKey(key)) {
      throw ApiException('USERNAME_TAKEN', '${user.username} is already taken.', statusCode: 409);
    }
    final created = AppUser(id: 'u${_nextId++}', name: user.name, username: key, role: user.role, phone: user.phone);
    accounts.add(created);
    _passwords[key] = user.password;
    return created;
  }

  @override
  Future<AppUser> updateUser(String id, UserChanges changes) async {
    final index = accounts.indexWhere((u) => u.id == id);
    final old = accounts[index];
    final updated = AppUser(
      id: id,
      name: changes.name,
      username: old.username,
      role: changes.role,
      phone: changes.phone,
    );
    accounts[index] = updated;
    if (changes.password.isNotEmpty) _passwords[old.username] = changes.password;
    return updated;
  }

  @override
  Future<void> removeUser(String id) async {
    final user = accounts.firstWhere((u) => u.id == id);
    if (user.role == UserRole.admin) {
      throw const ApiException(
        'CANNOT_REMOVE_ADMIN',
        'Admins cannot be removed. Change their role first if they no longer need Admin access.',
        statusCode: 409,
      );
    }
    accounts.remove(user);
    _passwords.remove(user.username);
  }
}
