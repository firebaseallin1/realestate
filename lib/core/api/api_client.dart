import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// A failed API call: a stable [code] and a [message] to show the user.
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const ApiException(this.code, this.message, {this.statusCode});

  static const ApiException unreachable = ApiException(
    'NETWORK',
    'Cannot reach the server. Check your connection and try again.',
  );

  @override
  String toString() => message;
}

/// Keeps the refresh token between app runs.
abstract class TokenStore {
  Future<String?> read();
  Future<void> save(String refreshToken);
  Future<void> clear();
}

/// The device's secure storage. Where it is unavailable the user simply has
/// to sign in each time, so failures are not errors.
class SecureTokenStore implements TokenStore {
  static const _key = 'refresh_token';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (error) {
      debugPrint('Could not read the saved sign-in: $error');
      return null;
    }
  }

  @override
  Future<void> save(String refreshToken) async {
    try {
      await _storage.write(key: _key, value: refreshToken);
    } catch (error) {
      debugPrint('Could not save the sign-in: $error');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (error) {
      debugPrint('Could not clear the saved sign-in: $error');
    }
  }
}

/// ApiClient makes every call to the backend. It adds the access token, and
/// when that expires swaps the refresh token for a new pair and retries, so
/// callers never see an expired token.
class ApiClient {
  ApiClient({http.Client? httpClient, TokenStore? tokens, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      _tokens = tokens ?? SecureTokenStore(),
      _baseUrl = baseUrl ?? defaultBaseUrl;

  static final ApiClient instance = ApiClient();

  /// Set with --dart-define=API_BASE_URL=... An Android emulator reaches this
  /// computer at 10.0.2.2; a real phone needs the computer's network address.
  static String get defaultBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:1001/api/v1' : 'http://localhost:1001/api/v1';
  }

  static const _timeout = Duration(seconds: 20);

  final http.Client _http;
  final TokenStore _tokens;
  final String _baseUrl;
  String? _accessToken;

  /// Calls waiting on a token refresh share this one, as each token works once.
  Future<Map<String, dynamic>?>? _refreshing;

  /// Called when the sign-in has ended and the user must sign in again.
  VoidCallback? onSessionExpired;

  bool get isSignedIn => _accessToken != null;

  Future<Map<String, dynamic>?> get(String path, {Map<String, String>? query, bool authenticated = true}) =>
      _send('GET', path, query: query, authenticated: authenticated);

  Future<Map<String, dynamic>?> post(String path, {Object? body, bool authenticated = true}) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>?> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<Map<String, dynamic>?> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<Map<String, dynamic>?> delete(String path) => _send('DELETE', path);

  /// Sends a file as a multipart form.
  Future<Map<String, dynamic>?> upload(String path, String name, Uint8List bytes) async {
    return _decode(
      await _sendWithRefresh('POST', path, file: () => http.MultipartFile.fromBytes('file', bytes, filename: name)),
    );
  }

  /// Fetches a file's bytes.
  Future<Uint8List> download(String path) async {
    final response = await _sendWithRefresh('GET', path);
    if (response.statusCode >= 200 && response.statusCode < 300) return response.bodyBytes;
    _decode(response);
    throw const ApiException('REQUEST_FAILED', 'Could not load this file.');
  }

  /// Keeps the tokens from a sign-in or refresh response.
  Future<void> saveSession(Map<String, dynamic> session) async {
    _accessToken = session['accessToken'] as String;
    await _tokens.save(session['refreshToken'] as String);
  }

  /// Signs back in from the saved token, returning the session with its user.
  /// Null when there is no saved sign-in, or the server cannot be reached.
  Future<Map<String, dynamic>?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      return await _refresh(notifyExpired: false);
    } on ApiException {
      return null;
    }
  }

  /// Ends the sign-in here at once, then tells the server if it can be reached.
  Future<void> endSession() async {
    final refreshToken = await _tokens.read();
    _accessToken = null;
    await _tokens.clear();
    if (refreshToken == null) return;
    try {
      await _send('POST', '/auth/logout', body: {'refreshToken': refreshToken}, authenticated: false);
    } on ApiException catch (error) {
      debugPrint('Could not reach the server to sign out: $error');
    }
  }

  Future<Map<String, dynamic>?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    return _decode(await _sendWithRefresh(method, path, body: body, query: query, authenticated: authenticated));
  }

  Future<http.Response> _sendWithRefresh(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    http.MultipartFile Function()? file,
    bool authenticated = true,
  }) async {
    var response = await _request(method, path, body: body, query: query, file: file, authenticated: authenticated);

    if (response.statusCode == 401 && authenticated && _accessToken != null) {
      await _refresh(notifyExpired: true);
      response = await _request(method, path, body: body, query: query, file: file, authenticated: true);
    }
    return response;
  }

  Future<Map<String, dynamic>?> _refresh({required bool notifyExpired}) {
    return _refreshing ??= _performRefresh(notifyExpired).whenComplete(() => _refreshing = null);
  }

  Future<Map<String, dynamic>?> _performRefresh(bool notifyExpired) async {
    // Read each time: another browser tab may have replaced the token.
    final refreshToken = await _tokens.read();
    final response = refreshToken == null
        ? null
        : await _request('POST', '/auth/refresh', body: {'refreshToken': refreshToken}, authenticated: false);

    if (response == null || response.statusCode == 401) {
      _accessToken = null;
      await _tokens.clear();
      if (notifyExpired) onSessionExpired?.call();
      throw const ApiException('SESSION_ENDED', 'Please sign in again.', statusCode: 401);
    }

    final session = _decode(response)!;
    await saveSession(session);
    return session;
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    http.MultipartFile Function()? file,
    required bool authenticated,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final http.BaseRequest request;
    if (file != null) {
      // Made fresh for each try, as a file's stream can only be read once.
      request = http.MultipartRequest(method, uri)..files.add(file());
    } else {
      final plain = http.Request(method, uri);
      if (body != null) {
        plain.headers['Content-Type'] = 'application/json';
        plain.body = jsonEncode(body);
      }
      request = plain;
    }
    request.headers['Accept'] = 'application/json';
    if (authenticated && _accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }

    try {
      return await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on TimeoutException {
      throw ApiException.unreachable;
    } on http.ClientException {
      throw ApiException.unreachable;
    } catch (error) {
      // A closed socket surfaces differently on each platform.
      debugPrint('Request failed: $error');
      throw ApiException.unreachable;
    }
  }

  Map<String, dynamic>? _decode(http.Response response) {
    Object? json;
    if (response.body.isNotEmpty) {
      try {
        json = jsonDecode(response.body);
      } on FormatException {
        json = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json is Map<String, dynamic> ? json : null;
    }
    if (json is Map<String, dynamic> && json['message'] is String) {
      throw ApiException(
        json['code'] as String? ?? 'REQUEST_FAILED',
        json['message'] as String,
        statusCode: response.statusCode,
      );
    }
    throw ApiException('REQUEST_FAILED', 'Something went wrong. Please try again.', statusCode: response.statusCode);
  }
}
