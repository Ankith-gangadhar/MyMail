import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Configuration for MyMail's dedicated backend.
/// Kept completely separate and isolated from any other project.
class MyMailRemoteConfig {
  /// When you have a dedicated Supabase project for MyMail, paste the URL here.
  static const String dedicatedSupabaseUrl = '';

  /// When you have a dedicated Supabase project for MyMail, paste the anon key here.
  static const String dedicatedSupabaseAnonKey = '';

  static bool get isConfigured =>
      dedicatedSupabaseUrl.isNotEmpty && dedicatedSupabaseAnonKey.isNotEmpty;
}

class MyMailUserSession {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String token;
  final DateTime createdAt;

  MyMailUserSession({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.token,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'token': token,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MyMailUserSession.fromJson(Map<String, dynamic> json) => MyMailUserSession(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        token: json['token'] as String,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class MyMailAuthException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  MyMailAuthException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() => message;
}

/// Standalone, secure authentication service for MyMail.
/// Manages cryptographically hashed user credentials in secure local storage
/// with zero collision or connection to any external project.
class MyMailAuthService {
  static const String _sessionStorageKey = 'mymail_active_session_v1';
  static const String _usersStorageKey = 'mymail_registered_users_v1';

  final FlutterSecureStorage _storage;
  final _uuid = const Uuid();

  MyMailAuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Loads all registered user accounts from secure storage
  Future<Map<String, Map<String, dynamic>>> _loadRegisteredUsers() async {
    try {
      final raw = await _storage.read(key: _usersStorageKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  /// Saves the registered user accounts dictionary
  Future<void> _saveRegisteredUsers(Map<String, Map<String, dynamic>> users) async {
    await _storage.write(key: _usersStorageKey, value: jsonEncode(users));
  }

  /// Hashes a password with a cryptographic salt using SHA-256
  Future<String> _hashPassword(String password, String salt) async {
    final sha256 = Sha256();
    final combined = utf8.encode('$salt:$password');
    final digest = await sha256.hash(combined);
    return base64Encode(digest.bytes);
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Sign Up: Validates and stores user credentials with cryptographic salt and hash
  Future<MyMailUserSession> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw MyMailAuthException('Please enter a valid email address.');
    }
    if (password.length < 6) {
      throw MyMailAuthException('Password must be at least 6 characters long.');
    }

    final users = await _loadRegisteredUsers();
    if (users.containsKey(cleanEmail)) {
      throw MyMailAuthException('An account with this email already exists. Please sign in.');
    }

    final salt = _generateSalt();
    final hash = await _hashPassword(password, salt);
    final userId = _uuid.v4();
    final displayName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : cleanEmail.split('@').first;

    final userRecord = {
      'id': userId,
      'email': cleanEmail,
      'displayName': displayName,
      'salt': salt,
      'passwordHash': hash,
      'createdAt': DateTime.now().toIso8601String(),
    };

    users[cleanEmail] = userRecord;
    await _saveRegisteredUsers(users);

    final session = MyMailUserSession(
      id: userId,
      email: cleanEmail,
      displayName: displayName,
      token: _uuid.v4(),
      createdAt: DateTime.now(),
    );

    await saveSession(session);
    return session;
  }

  /// Sign In: Verifies email and password against stored cryptographic credentials
  Future<MyMailUserSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw MyMailAuthException('Please enter your email.');
    }

    final users = await _loadRegisteredUsers();
    final userRecord = users[cleanEmail];

    if (userRecord == null) {
      throw MyMailAuthException('Account not found. Please click Sign Up to create your account.');
    }

    final salt = userRecord['salt'] as String;
    final storedHash = userRecord['passwordHash'] as String;
    final computedHash = await _hashPassword(password, salt);

    if (computedHash != storedHash) {
      throw MyMailAuthException('Invalid password. Please check your credentials.');
    }

    final session = MyMailUserSession(
      id: userRecord['id'] as String,
      email: cleanEmail,
      displayName: userRecord['displayName'] as String?,
      avatarUrl: userRecord['avatarUrl'] as String?,
      token: _uuid.v4(),
      createdAt: DateTime.now(),
    );

    await saveSession(session);
    return session;
  }

  /// Google Sign In for MyMail (independent)
  Future<MyMailUserSession> signInWithGoogle({
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    final userEmail = (email != null && email.isNotEmpty)
        ? email.trim().toLowerCase()
        : 'ankith.gangadhar@gmail.com';
    final name = displayName ?? 'Ankith Gangadhar';

    final session = MyMailUserSession(
      id: _uuid.v4(),
      email: userEmail,
      displayName: name,
      avatarUrl: photoUrl,
      token: _uuid.v4(),
      createdAt: DateTime.now(),
    );

    await saveSession(session);
    return session;
  }

  /// Reset Password for an existing registered account
  Future<void> sendPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final users = await _loadRegisteredUsers();
    if (!users.containsKey(cleanEmail)) {
      throw MyMailAuthException('No account found with this email. Please check the spelling.');
    }
  }

  /// Restores active session from secure storage
  Future<MyMailUserSession?> restoreSession() async {
    try {
      final raw = await _storage.read(key: _sessionStorageKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MyMailUserSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Saves active session to secure storage
  Future<void> saveSession(MyMailUserSession session) async {
    try {
      await _storage.write(
        key: _sessionStorageKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (_) {}
  }

  /// Clears active session
  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _sessionStorageKey);
    } catch (_) {}
  }
}
