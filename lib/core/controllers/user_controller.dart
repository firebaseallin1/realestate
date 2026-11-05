import 'package:flutter/foundation.dart';
import '../../models/app_user.dart';

/// UserController holds the team's accounts (in memory for now): sign-in
/// checks, and the Admin's Users page (add and remove).
class UserController extends ChangeNotifier {
  UserController._() {
    _seedUsers();
  }

  /// A fresh controller with the demo accounts, for tests.
  @visibleForTesting
  UserController.test() {
    _seedUsers();
  }

  static final UserController instance = UserController._();

  final List<AppUser> _users = [];
  int _nextId = 1;

  /// Demo password shared by the seeded accounts.
  static const String demoPassword = 'kaira123';

  void _seedUsers() {
    _users.addAll(const [
      AppUser(id: 'u1', name: 'Admin', username: 'admin', password: demoPassword, role: UserRole.admin, phone: '98480 11111'),
      AppUser(id: 'u2', name: 'Priya Sharma', username: 'sales', password: demoPassword, role: UserRole.salesExecutive, phone: '98480 22222'),
      AppUser(id: 'u3', name: 'Ravi Kumar', username: 'manager', password: demoPassword, role: UserRole.siteManager, phone: '98480 33333'),
      AppUser(id: 'u4', name: 'Suresh Reddy', username: 'incharge', password: demoPassword, role: UserRole.siteIncharge, phone: '98480 44444'),
    ]);
    _nextId = _users.length + 1;
  }

  List<AppUser> get users => List.unmodifiable(_users);

  List<AppUser> usersWithRole(UserRole? role) =>
      role == null ? users : _users.where((u) => u.role == role).toList();

  int countWithRole(UserRole role) => _users.where((u) => u.role == role).length;

  AppUser? findByUsername(String username) {
    final key = username.trim().toLowerCase();
    for (final user in _users) {
      if (user.username.toLowerCase() == key) return user;
    }
    return null;
  }

  bool isUsernameTaken(String username) => findByUsername(username) != null;

  /// The user with these credentials, or null. Usernames ignore case.
  AppUser? authenticate(String username, String password) {
    final user = findByUsername(username);
    return user != null && user.password == password ? user : null;
  }

  String newId() => 'u${_nextId++}';

  void addUser(AppUser user) {
    _users.add(user);
    notifyListeners();
  }

  void removeUser(String id) {
    _users.removeWhere((u) => u.id == id);
    notifyListeners();
  }
}
