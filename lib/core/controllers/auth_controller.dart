import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../api/api_client.dart';
import '../repositories/auth_repository.dart';

/// AuthController manages authentication state and user sessions.
class AuthController extends ChangeNotifier {
  final AuthRepository _repository;

  AuthController({AuthRepository? repository}) : _repository = repository ?? ApiAuthRepository();

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

  /// Signs in: returns the user (whose role picks the menu and dashboard),
  /// or null with [errorMessage] set.
  Future<AppUser?> login({required String username, required String password}) async {
    if (username.trim().isEmpty) {
      _fail('Please enter your username.');
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.login(username, password);
      _isLoading = false;
      notifyListeners();
      return user;
    } on ApiException catch (error) {
      _fail(error.message);
      return null;
    } catch (error) {
      debugPrint('Sign-in failed: $error');
      _fail('Authentication failed. Please try again.');
      return null;
    }
  }

  /// The user of a saved sign-in, so the app can skip the login screen.
  Future<AppUser?> restoreSession() async {
    try {
      return await _repository.restoreSession();
    } catch (error) {
      debugPrint('Could not resume the sign-in: $error');
      return null;
    }
  }

  Future<void> logout() => _repository.logout();
}
