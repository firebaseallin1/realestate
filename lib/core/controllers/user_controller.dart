import 'package:flutter/foundation.dart';

import '../../models/app_user.dart';
import '../api/api_client.dart';
import '../repositories/local_user_repository.dart';
import '../repositories/user_repository.dart';

/// UserController holds the team's accounts for the Admin's Users page and
/// the Site Incharge pickers. Which accounts arrive depends on the role: the
/// server gives a Site Manager only the Site Incharges.
class UserController extends ChangeNotifier {
  UserController(this.repository);

  /// A fresh controller with the demo accounts already loaded, for tests.
  @visibleForTesting
  UserController.test() : repository = LocalUserRepository() {
    _users.addAll((repository as LocalUserRepository).accounts);
  }

  static final UserController instance = UserController(ApiUserRepository());

  final UserRepository repository;
  final List<AppUser> _users = [];
  bool _isLoading = false;
  String? _loadError;

  bool get isLoading => _isLoading;

  /// Why the last load failed, for the page to show with a retry.
  String? get loadError => _loadError;

  List<AppUser> get users => List.unmodifiable(_users);

  List<AppUser> usersWithRole(UserRole? role) => role == null ? users : _users.where((u) => u.role == role).toList();

  int countWithRole(UserRole role) => _users.where((u) => u.role == role).length;

  AppUser? findByUsername(String username) {
    final key = username.trim().toLowerCase();
    for (final user in _users) {
      if (user.username.toLowerCase() == key) return user;
    }
    return null;
  }

  bool isUsernameTaken(String username) => findByUsername(username) != null;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final users = await repository.fetchUsers();
      _users
        ..clear()
        ..addAll(users);
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds the user on the server. Throws an ApiException if it refuses.
  Future<AppUser> addUser(NewUser user) async {
    final created = await repository.createUser(user);
    _users.add(created);
    notifyListeners();
    return created;
  }

  /// Saves changes to an account. Throws an ApiException if the server refuses.
  Future<AppUser> updateUser(String id, UserChanges changes) async {
    final updated = await repository.updateUser(id, changes);
    final index = _users.indexWhere((u) => u.id == id);
    if (index >= 0) _users[index] = updated;
    notifyListeners();
    return updated;
  }

  /// Removes the user on the server. Throws an ApiException if it refuses.
  Future<void> removeUser(String id) async {
    await repository.removeUser(id);
    _users.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  /// Forgets the accounts on sign-out, so the next user cannot see them.
  void clear() {
    _users.clear();
    _loadError = null;
    notifyListeners();
  }
}
