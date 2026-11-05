import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import 'user_controller.dart';

/// AuthController manages authentication state and user sessions.
class AuthController extends ChangeNotifier {
  final UserController _users;

  AuthController({UserController? users}) : _users = users ?? UserController.instance;

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _fail(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  /// Simulated login call: returns the signed-in user (whose role picks
  /// the menu and dashboard), or null with [errorMessage] set.
  Future<AppUser?> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate real-world network latency
      await Future.delayed(const Duration(milliseconds: 1400));

      if (username.trim().isEmpty) {
        _fail('Please enter your username.');
        return null;
      }

      if (password.trim().length < 6) {
        _fail('Password must be at least 6 characters.');
        return null;
      }

      final user = _users.authenticate(username, password);
      if (user == null) {
        _fail('Incorrect username or password.');
        return null;
      }

      _isLoading = false;
      notifyListeners();
      return user;
    } catch (e) {
      _fail('Authentication failed. Please try again.');
      return null;
    }
  }
}
