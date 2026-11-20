import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:real_estate/core/api/api_client.dart';
import 'package:real_estate/core/controllers/auth_controller.dart';
import 'package:real_estate/core/controllers/user_controller.dart';
import 'package:real_estate/core/repositories/auth_repository.dart';
import 'package:real_estate/core/repositories/user_repository.dart';
import 'package:real_estate/models/app_user.dart';
import 'package:real_estate/screens/dashboard/sections/users_section.dart';
import 'package:real_estate/screens/dashboard/widgets/user_form.dart';

class _MemoryTokens implements TokenStore {
  String? token;

  _MemoryTokens([this.token]);

  @override
  Future<String?> read() async => token;
  @override
  Future<void> save(String refreshToken) async => token = refreshToken;
  @override
  Future<void> clear() async => token = null;
}

const _userJson = {'id': 'abc', 'name': 'Priya', 'username': 'sales', 'role': 'salesExecutive', 'phone': ''};

Map<String, dynamic> _session(String suffix) => {
      'accessToken': 'access-$suffix',
      'refreshToken': 'refresh-$suffix',
      'user': _userJson,
    };

http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status);

void main() {
  group('ApiClient', () {
    test('Login keeps the refresh token and sends the access token afterwards', () async {
      final tokens = _MemoryTokens();
      String? authHeader;
      final api = ApiClient(
        tokens: tokens,
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            expect(request.headers['Authorization'], isNull);
            expect(jsonDecode(request.body), {'username': 'sales', 'password': 'pw'});
            return _json(_session('1'));
          }
          authHeader = request.headers['Authorization'];
          return _json({'items': []});
        }),
      );

      final user = await ApiAuthRepository(api: api).login(' sales ', 'pw');
      expect(user.role, UserRole.salesExecutive);
      expect(tokens.token, 'refresh-1');
      expect(api.isSignedIn, isTrue);

      await api.get('/users');
      expect(authHeader, 'Bearer access-1');
    });

    test('A wrong password shows the server message and does not try to refresh', () async {
      var calls = 0;
      final api = ApiClient(
        tokens: _MemoryTokens(),
        baseUrl: 'http://x',
        httpClient: MockClient((_) async {
          calls++;
          return _json({'code': 'INVALID_CREDENTIALS', 'message': 'Incorrect username or password.'}, 401);
        }),
      );
      final auth = AuthController(repository: ApiAuthRepository(api: api));

      expect(await auth.login(username: 'a', password: 'b'), isNull);
      expect(auth.errorMessage, 'Incorrect username or password.');
      expect(auth.isLoading, isFalse);
      expect(calls, 1);
    });

    test('An expired token refreshes once and retries, even for calls at the same time', () async {
      final tokens = _MemoryTokens();
      var refreshes = 0;
      var current = 'access-1';
      final api = ApiClient(
        tokens: tokens,
        baseUrl: 'http://x',
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            refreshes++;
            expect(jsonDecode(request.body), {'refreshToken': 'refresh-1'});
            current = 'access-2';
            return _json(_session('2'));
          }
          return request.headers['Authorization'] == 'Bearer $current' && current == 'access-2'
              ? _json({'ok': true})
              : _json({'code': 'UNAUTHORIZED', 'message': 'Please sign in again.'}, 401);
        }),
      );
      await api.saveSession(_session('1'));

      final results = await Future.wait([api.get('/a'), api.get('/b'), api.get('/c')]);
      expect(results.every((r) => r!['ok'] == true), isTrue);
      expect(refreshes, 1);
      expect(tokens.token, 'refresh-2');
    });

    test('When the sign-in has ended it clears tokens and tells the app', () async {
      final tokens = _MemoryTokens();
      var expired = 0;
      final api = ApiClient(
        tokens: tokens,
        baseUrl: 'http://x',
        httpClient: MockClient((_) async => _json({'code': 'UNAUTHORIZED', 'message': 'Please sign in again.'}, 401)),
      )..onSessionExpired = () => expired++;
      await api.saveSession(_session('1'));

      await expectLater(api.get('/users'), throwsA(isA<ApiException>()));
      expect(expired, 1);
      expect(tokens.token, isNull);
      expect(api.isSignedIn, isFalse);
    });

    test('A network failure keeps the sign-in and gives a clear message', () async {
      final tokens = _MemoryTokens();
      var expired = 0;
      var online = true;
      final api = ApiClient(
        tokens: tokens,
        baseUrl: 'http://x',
        httpClient: MockClient((request) async {
          if (!online) throw http.ClientException('no route');
          return _json({'code': 'UNAUTHORIZED', 'message': 'x'}, 401);
        }),
      )..onSessionExpired = () => expired++;
      await api.saveSession(_session('1'));

      online = false;
      await expectLater(
        api.get('/users'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Cannot reach the server'))),
      );

      // Access token expired while the refresh itself cannot get through.
      var attempt = 0;
      final flaky = ApiClient(
        tokens: tokens,
        baseUrl: 'http://x',
        httpClient: MockClient((_) async {
          if (attempt++ == 0) return _json({'code': 'UNAUTHORIZED', 'message': 'x'}, 401);
          throw http.ClientException('no route');
        }),
      )..onSessionExpired = () => expired++;
      await flaky.saveSession(_session('3'));
      await expectLater(flaky.get('/users'), throwsA(isA<ApiException>()));
      expect(tokens.token, 'refresh-3');
      expect(expired, 0);
    });

    test('Unexpected responses do not crash', () async {
      final api = ApiClient(
        tokens: _MemoryTokens(),
        baseUrl: 'http://x',
        httpClient: MockClient((_) async => http.Response('<html>Bad gateway</html>', 502)),
      );
      await expectLater(
        api.get('/users'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Something went wrong. Please try again.')),
      );
    });

    test('Resuming: saved token signs in; none, or a dead one, goes to login', () async {
      final saved = _MemoryTokens('refresh-1');
      final resumed = ApiClient(
        tokens: saved,
        baseUrl: 'http://x',
        httpClient: MockClient((_) async => _json(_session('2'))),
      );
      expect((await ApiAuthRepository(api: resumed).restoreSession())?.username, 'sales');
      expect(saved.token, 'refresh-2');

      var calls = 0;
      final none = ApiClient(
        tokens: _MemoryTokens(),
        baseUrl: 'http://x',
        httpClient: MockClient((_) async {
          calls++;
          return _json({});
        }),
      );
      expect(await ApiAuthRepository(api: none).restoreSession(), isNull);
      expect(calls, 0);

      final dead = _MemoryTokens('refresh-old');
      var expired = 0;
      final ended = ApiClient(
        tokens: dead,
        baseUrl: 'http://x',
        httpClient: MockClient((_) async => _json({'code': 'SESSION_ENDED', 'message': 'x'}, 401)),
      )..onSessionExpired = () => expired++;
      expect(await ApiAuthRepository(api: ended).restoreSession(), isNull);
      expect(dead.token, isNull);
      expect(expired, 0); // Already heading to login; no extra navigation.
    });

    test('Logout clears locally even if the server is unreachable', () async {
      final tokens = _MemoryTokens();
      final api = ApiClient(
        tokens: tokens,
        baseUrl: 'http://x',
        httpClient: MockClient((_) async => throw http.ClientException('offline')),
      );
      await api.saveSession(_session('1'));
      await ApiAuthRepository(api: api).logout();
      expect(tokens.token, isNull);
      expect(api.isSignedIn, isFalse);
    });
  });

  group('Users over the API', () {
    test('Loads, adds and removes through the endpoints', () async {
      final seen = <String>[];
      final api = ApiClient(
        tokens: _MemoryTokens(),
        baseUrl: 'http://x',
        httpClient: MockClient((request) async {
          seen.add('${request.method} ${request.url.path}');
          if (request.method == 'GET') {
            expect(request.url.queryParameters['limit'], '200');
            return _json({'items': [_userJson], 'total': 1});
          }
          if (request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['role'], 'siteIncharge');
            expect(body['password'], 'secret12');
            return _json({'id': 'new', 'name': body['name'], 'username': 'anil', 'role': body['role'], 'phone': ''}, 201);
          }
          return http.Response('', 204);
        }),
      );
      final users = UserController(ApiUserRepository(api: api));

      await users.load();
      expect(users.users.single.id, 'abc');

      final added = await users.addUser(
        const NewUser(name: 'Anil', username: 'anil', password: 'secret12', role: UserRole.siteIncharge),
      );
      expect(added.id, 'new');
      expect(users.users.length, 2);

      await users.removeUser('new');
      expect(users.users.length, 1);
      expect(seen, ['GET /users', 'POST /users', 'DELETE /users/new']);
    });
  });

  group('Screens', () {
    testWidgets('The Add User form shows the server\'s refusal and stays open', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UserForm(
                isUsernameTaken: (_) => false,
                onSubmit: (_) async => 'anil is already taken.',
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('user-name')), 'Anil');
      await tester.enterText(find.byKey(const ValueKey('user-username')), 'anil');
      await tester.enterText(find.byKey(const ValueKey('user-password')), 'secret12');
      await tester.ensureVisible(find.byKey(const ValueKey('user-role')));
      await tester.tap(find.byKey(const ValueKey('user-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales Executive').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('user-submit')));
      await tester.tap(find.byKey(const ValueKey('user-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('user-form-error')), findsOneWidget);
      expect(find.text('anil is already taken.'), findsOneWidget);
      expect(find.byType(UserForm), findsOneWidget);
    });

    testWidgets('The Users page shows an error with a retry that works', (tester) async {
      final repository = _FlakyUsers();
      final users = UserController(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: users,
              builder: (_, _) => UsersSection(controller: users, currentUserId: 'x', onRemoveUser: (_) {}),
            ),
          ),
        ),
      );

      users.load();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Cannot reach the server. Check your connection and try again.'), findsOneWidget);

      repository.online = true;
      await tester.tap(find.byKey(const ValueKey('users-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Priya'), findsOneWidget);
    });
  });
}

class _FlakyUsers implements UserRepository {
  bool online = false;

  @override
  Future<List<AppUser>> fetchUsers() async {
    await Future<void>.delayed(Duration.zero);
    if (!online) throw ApiException.unreachable;
    return [AppUser.fromJson(_userJson)];
  }

  @override
  Future<AppUser> createUser(NewUser user) => throw UnimplementedError();

  @override
  Future<AppUser> updateUser(String id, UserChanges changes) => throw UnimplementedError();

  @override
  Future<void> removeUser(String id) => throw UnimplementedError();
}
