import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class SupabaseUserSession {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String accessToken;
  final String? refreshToken;

  SupabaseUserSession({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.accessToken,
    this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };

  factory SupabaseUserSession.fromJson(Map<String, dynamic> json) => SupabaseUserSession(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
      );
}

class SupabaseAuthException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  SupabaseAuthException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() => message;
}

/// Supabase Authentication Service (Connecting to mangalorefoods Supabase backend)
class SupabaseAuthService {
  static const String supabaseUrl = 'https://fgvcnxylpocxlrjewyhq.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_IK-fnzl1WmWD1H6GPnYg3g_tbilS6VK';
  static const String _sessionStorageKey = 'mymail_supabase_session_v1';

  final http.Client _client;
  final FlutterSecureStorage _storage;

  SupabaseAuthService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Map<String, String> get _headers => {
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json',
      };

  /// Sign Up with Email and Password
  Future<SupabaseUserSession> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (password.length < 6) {
      throw SupabaseAuthException('Password must be at least 6 characters long.');
    }

    final url = Uri.parse('$supabaseUrl/auth/v1/signup');
    final body = jsonEncode({
      'email': cleanEmail,
      'password': password,
      'data': {
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (name != null && name.trim().isNotEmpty) 'full_name': name.trim(),
      },
    });

    final res = await _client.post(url, headers: _headers, body: body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final user = json['user'] as Map<String, dynamic>? ?? json;
      final userId = user['id'] as String;
      final accessToken = (json['access_token'] as String?) ?? '';
      final refreshToken = json['refresh_token'] as String?;
      final metadata = (user['user_metadata'] as Map<String, dynamic>?) ?? {};
      final displayName = metadata['name'] as String? ?? metadata['full_name'] as String? ?? name;
      final avatarUrl = metadata['avatar_url'] as String? ?? metadata['picture'] as String?;

      final session = SupabaseUserSession(
        id: userId,
        email: cleanEmail,
        displayName: displayName,
        avatarUrl: avatarUrl,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      if (accessToken.isNotEmpty) {
        await saveSession(session);
      }
      return session;
    } else {
      _handleAuthError(res);
      throw SupabaseAuthException('Sign-up failed. Please try again.');
    }
  }

  /// Sign In with Email and Password (validates credentials against Supabase auth.users)
  Future<SupabaseUserSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final url = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');
    final body = jsonEncode({
      'email': cleanEmail,
      'password': password,
    });

    final res = await _client.post(url, headers: _headers, body: body);

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final accessToken = json['access_token'] as String;
      final refreshToken = json['refresh_token'] as String?;
      final user = json['user'] as Map<String, dynamic>;
      final userId = user['id'] as String;
      final metadata = (user['user_metadata'] as Map<String, dynamic>?) ?? {};
      final displayName = metadata['name'] as String? ?? metadata['full_name'] as String?;
      final avatarUrl = metadata['avatar_url'] as String? ?? metadata['picture'] as String?;

      final session = SupabaseUserSession(
        id: userId,
        email: cleanEmail,
        displayName: displayName,
        avatarUrl: avatarUrl,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      await saveSession(session);
      return session;
    } else {
      _handleAuthError(res);
      throw SupabaseAuthException('Sign-in failed. Please check your credentials.');
    }
  }

  /// Sends a password recovery email via Supabase
  Future<void> sendPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final url = Uri.parse('$supabaseUrl/auth/v1/recover');
    final body = jsonEncode({'email': cleanEmail});

    try {
      final res = await _client.post(url, headers: _headers, body: body);
      if (res.statusCode >= 400 && res.statusCode < 500) {
        _handleAuthError(res);
      }
    } catch (e) {
      if (e is SupabaseAuthException) rethrow;
      // In case default SMTP is unconfigured on free Supabase tier, notify gracefully
      debugPrint('Supabase recovery note: $e');
    }
  }

  /// Generates the Google OAuth authorization URL for Web/Browser
  String getGoogleOAuthUrl({String? redirectUrl}) {
    final redirect = redirectUrl ??
        (kIsWeb
            ? (Uri.base.hasPort ? '${Uri.base.scheme}://${Uri.base.host}:${Uri.base.port}' : '${Uri.base.scheme}://${Uri.base.host}')
            : 'https://mangalorefoods.in/auth/callback');

    return '$supabaseUrl/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(redirect)}';
  }

  /// Exchanges a Google ID Token directly with Supabase
  Future<SupabaseUserSession> signInWithIdToken({
    required String idToken,
    String? nonce,
  }) async {
    final url = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=id_token');
    final body = jsonEncode({
      'provider': 'google',
      'id_token': idToken,
      if (nonce != null) 'nonce': nonce,
    });

    final res = await _client.post(url, headers: _headers, body: body);

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final accessToken = json['access_token'] as String;
      final refreshToken = json['refresh_token'] as String?;
      final user = json['user'] as Map<String, dynamic>;
      final userId = user['id'] as String;
      final email = user['email'] as String? ?? '';
      final metadata = (user['user_metadata'] as Map<String, dynamic>?) ?? {};
      final displayName = metadata['name'] as String? ?? metadata['full_name'] as String?;
      final avatarUrl = metadata['avatar_url'] as String? ?? metadata['picture'] as String?;

      final session = SupabaseUserSession(
        id: userId,
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      await saveSession(session);
      return session;
    } else {
      _handleAuthError(res);
      throw SupabaseAuthException('Google Sign-In verification failed.');
    }
  }

  /// Parses and verifies session if redirected back with `#access_token=...` in URL
  Future<SupabaseUserSession?> checkUrlFragmentSession(String fragment) async {
    if (!fragment.contains('access_token=')) return null;

    try {
      final cleanFragment = fragment.startsWith('#') ? fragment.substring(1) : fragment;
      final params = Uri.splitQueryString(cleanFragment);
      final accessToken = params['access_token'];
      final refreshToken = params['refresh_token'];

      if (accessToken == null || accessToken.isEmpty) return null;

      // Verify token with Supabase /auth/v1/user
      final userUrl = Uri.parse('$supabaseUrl/auth/v1/user');
      final res = await _client.get(
        userUrl,
        headers: {
          ..._headers,
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (res.statusCode == 200) {
        final user = jsonDecode(res.body) as Map<String, dynamic>;
        final userId = user['id'] as String;
        final email = user['email'] as String? ?? '';
        final metadata = (user['user_metadata'] as Map<String, dynamic>?) ?? {};
        final displayName = metadata['name'] as String? ?? metadata['full_name'] as String?;
        final avatarUrl = metadata['avatar_url'] as String? ?? metadata['picture'] as String?;

        final session = SupabaseUserSession(
          id: userId,
          email: email,
          displayName: displayName,
          avatarUrl: avatarUrl,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        await saveSession(session);
        return session;
      }
    } catch (e) {
      debugPrint('Error parsing URL fragment session: $e');
    }
    return null;
  }

  /// Persists session to secure local storage
  Future<void> saveSession(SupabaseUserSession session) async {
    try {
      await _storage.write(
        key: _sessionStorageKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (e) {
      debugPrint('Warning: Could not save session to storage: $e');
    }
  }

  /// Restores active session from secure storage and verifies it against Supabase
  Future<SupabaseUserSession?> restoreSession() async {
    try {
      final raw = await _storage.read(key: _sessionStorageKey);
      if (raw == null || raw.isEmpty) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = SupabaseUserSession.fromJson(json);

      if (session.accessToken.isEmpty) return null;

      // Verify token is still valid with Supabase /auth/v1/user
      final userUrl = Uri.parse('$supabaseUrl/auth/v1/user');
      final res = await _client.get(
        userUrl,
        headers: {
          ..._headers,
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      if (res.statusCode == 200) {
        return session;
      } else {
        await clearSession();
        return null;
      }
    } catch (e) {
      debugPrint('Warning: Could not restore session: $e');
      return null;
    }
  }

  /// Clears active session
  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _sessionStorageKey);
    } catch (_) {}
  }

  /// Error parser for Supabase Auth responses
  void _handleAuthError(http.Response res) {
    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final msg = json['msg'] as String? ??
          json['error_description'] as String? ??
          json['message'] as String? ??
          'Authentication failed';
      final errorCode = json['error_code'] as String? ?? json['error'] as String?;

      if (errorCode == 'invalid_credentials' || msg.toLowerCase().contains('invalid login credentials')) {
        throw SupabaseAuthException(
          'Invalid email or password. Please verify your credentials or create an account.',
          statusCode: res.statusCode,
          errorCode: errorCode,
        );
      } else if (errorCode == 'user_already_exists' || msg.toLowerCase().contains('user already registered')) {
        throw SupabaseAuthException(
          'An account with this email already exists. Please sign in.',
          statusCode: res.statusCode,
          errorCode: errorCode,
        );
      } else if (msg.toLowerCase().contains('password should be at least')) {
        throw SupabaseAuthException(
          'Password must be at least 6 characters long.',
          statusCode: res.statusCode,
          errorCode: errorCode,
        );
      }

      throw SupabaseAuthException(msg, statusCode: res.statusCode, errorCode: errorCode);
    } catch (e) {
      if (e is SupabaseAuthException) rethrow;
      throw SupabaseAuthException('Authentication request failed (HTTP ${res.statusCode}).',
          statusCode: res.statusCode);
    }
  }
}
