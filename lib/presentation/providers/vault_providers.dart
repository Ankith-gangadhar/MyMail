import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/crypto/vault_key_wrapping_service.dart';
import '../../core/security/biometric_service.dart';
import '../../core/security/key_storage_service.dart';
import '../../core/security/screen_protection_service.dart';
import '../../data/datasources/export_import_service.dart';
import '../../data/datasources/local_database.dart';
import '../../data/datasources/recovery_remote_service.dart';
import '../../data/datasources/mymail_auth_service.dart';
import '../../data/repositories/vault_repository_impl.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/credential_entity.dart';
import '../../domain/repositories/vault_repository.dart';

// Services
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final db = LocalDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final keyStorageServiceProvider = Provider<KeyStorageService>((ref) {
  return KeyStorageService();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final exportImportServiceProvider = Provider<ExportImportService>((ref) {
  return ExportImportService();
});

final vaultKeyWrappingServiceProvider = Provider<VaultKeyWrappingService>((ref) {
  return VaultKeyWrappingService();
});

final recoveryServiceProvider = Provider<RecoveryRemoteService>((ref) {
  return RecoveryRemoteService();
});

final myMailAuthServiceProvider = Provider<MyMailAuthService>((ref) {
  return MyMailAuthService();
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final keyStorage = ref.watch(keyStorageServiceProvider);
  return VaultRepositoryImpl(
    localDb: db,
    keyStorageService: keyStorage,
  );
});

// Auth State
enum AuthStatus {
  initial,
  checkingDeviceSecurity,
  deviceSecurityMissing,
  unauthenticated,
  locked,
  authenticated,
}

class AuthState {
  final AuthStatus status;
  final String autoLockTimeout; // 'immediate', '1min', '5min', 'never'
  final Set<String> unlockedCategoryIds;
  final DateTime lastActiveTime;
  final bool isScreenCaptureProtectionEnabled;
  final String? userEmail;
  final String? userDisplayName;
  final String? userPhotoUrl;
  final bool isSignedIn;

  const AuthState({
    required this.status,
    required this.autoLockTimeout,
    required this.unlockedCategoryIds,
    required this.lastActiveTime,
    this.isScreenCaptureProtectionEnabled = false,
    this.userEmail,
    this.userDisplayName,
    this.userPhotoUrl,
    this.isSignedIn = true,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? autoLockTimeout,
    Set<String>? unlockedCategoryIds,
    DateTime? lastActiveTime,
    bool? isScreenCaptureProtectionEnabled,
    String? userEmail,
    String? userDisplayName,
    String? userPhotoUrl,
    bool? isSignedIn,
  }) {
    return AuthState(
      status: status ?? this.status,
      autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
      unlockedCategoryIds: unlockedCategoryIds ?? this.unlockedCategoryIds,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      isScreenCaptureProtectionEnabled: isScreenCaptureProtectionEnabled ?? this.isScreenCaptureProtectionEnabled,
      userEmail: userEmail ?? this.userEmail,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      isSignedIn: isSignedIn ?? this.isSignedIn,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final BiometricService _biometricService;
  late final KeyStorageService _keyStorageService;
  late final RecoveryRemoteService _recoveryService;
  late final MyMailAuthService _authService;

  @override
  AuthState build() {
    _biometricService = ref.read(biometricServiceProvider);
    _keyStorageService = ref.read(keyStorageServiceProvider);
    _recoveryService = ref.read(recoveryServiceProvider);
    _authService = ref.read(myMailAuthServiceProvider);

    // Initial check
    Future.microtask(() => initialize());

    return AuthState(
      status: AuthStatus.unauthenticated,
      autoLockTimeout: '5min',
      unlockedCategoryIds: {'cat_work', 'cat_personal', 'cat_business'},
      lastActiveTime: DateTime.now(),
      isScreenCaptureProtectionEnabled: false,
      userEmail: null,
      userDisplayName: null,
      isSignedIn: false,
    );
  }

  Future<void> initialize() async {
    final timeout = await _keyStorageService.getAutoLockTimeout();
    final screenCaptureEnabled = await _keyStorageService.getScreenCaptureProtectionEnabled();
    await ScreenProtectionService.setProtection(screenCaptureEnabled);

    // 0. On Web, check if a redirect sign-in just completed
    if (kIsWeb) {
      try {
        final redirectResult = await _recoveryService.getRedirectResult();
        if (redirectResult?.user != null) {
          final user = redirectResult!.user!;
          state = state.copyWith(
            status: AuthStatus.authenticated,
            autoLockTimeout: timeout,
            unlockedCategoryIds: {'cat_work', 'cat_personal', 'cat_business'},
            isScreenCaptureProtectionEnabled: screenCaptureEnabled,
            userEmail: user.email,
            userDisplayName: user.displayName ?? user.email?.split('@').first,
            userPhotoUrl: user.photoURL,
            isSignedIn: true,
            lastActiveTime: DateTime.now(),
          );
          return;
        }
      } catch (e) {
        debugPrint('Web redirect auth check: $e');
      }
    }

    // 1. Check if Firebase Auth has an active user
    final currentUser = _recoveryService.currentUser;
    if (currentUser != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        autoLockTimeout: timeout,
        unlockedCategoryIds: {'cat_work', 'cat_personal', 'cat_business'},
        isScreenCaptureProtectionEnabled: screenCaptureEnabled,
        userEmail: currentUser.email,
        userDisplayName: currentUser.displayName ?? currentUser.email?.split('@').first,
        userPhotoUrl: currentUser.photoURL,
        isSignedIn: true,
        lastActiveTime: DateTime.now(),
      );
      return;
    }

    // 2. Check if a local session is stored
    final session = await _authService.restoreSession();
    if (session != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        autoLockTimeout: timeout,
        unlockedCategoryIds: {'cat_work', 'cat_personal', 'cat_business'},
        isScreenCaptureProtectionEnabled: screenCaptureEnabled,
        userEmail: session.email,
        userDisplayName: session.displayName ?? session.email.split('@').first,
        userPhotoUrl: session.avatarUrl,
        isSignedIn: true,
        lastActiveTime: DateTime.now(),
      );
      return;
    }

    // 3. Otherwise unauthenticated
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      autoLockTimeout: timeout,
      unlockedCategoryIds: {'cat_work', 'cat_personal', 'cat_business'},
      isScreenCaptureProtectionEnabled: screenCaptureEnabled,
      isSignedIn: false,
      userEmail: null,
      userDisplayName: null,
      lastActiveTime: DateTime.now(),
    );
  }

  /// Sign In with Google via Firebase Auth
  Future<void> signInWithGoogle() async {
    try {
      final cred = await _recoveryService.signInWithGoogle();
      final user = cred.user;
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userEmail: user?.email ?? 'user@gmail.com',
        userDisplayName: user?.displayName ?? 'MyMail User',
        userPhotoUrl: user?.photoURL,
        isSignedIn: true,
        lastActiveTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Google Sign-In note: $e');
      rethrow;
    }
  }

  /// Sign In with Email & Password via Firebase Auth
  Future<void> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw Exception('Please enter both email and password.');
    }

    try {
      final cred = await _recoveryService.signInWithEmail(cleanEmail, password);
      final user = cred.user;
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userEmail: user?.email ?? cleanEmail,
        userDisplayName: user?.displayName ?? cleanEmail.split('@').first,
        userPhotoUrl: user?.photoURL,
        isSignedIn: true,
        lastActiveTime: DateTime.now(),
      );
    } catch (e) {
      // Fallback check against local vault
      try {
        final session = await _authService.signInWithPassword(
          email: cleanEmail,
          password: password,
        );
        state = state.copyWith(
          status: AuthStatus.authenticated,
          userEmail: session.email,
          userDisplayName: session.displayName ?? session.email.split('@').first,
          userPhotoUrl: session.avatarUrl,
          isSignedIn: true,
          lastActiveTime: DateTime.now(),
        );
        return;
      } catch (_) {}
      rethrow;
    }
  }

  /// Create Account with Email & Password via Firebase Auth
  Future<void> signUpWithEmail(String email, String password, String name) async {
    final cleanEmail = email.trim();
    try {
      final cred = await _recoveryService.signUpWithEmail(cleanEmail, password, name);
      final user = cred.user;
      try {
        await _authService.signUp(email: cleanEmail, password: password, name: name);
      } catch (_) {}

      state = state.copyWith(
        status: AuthStatus.authenticated,
        userEmail: user?.email ?? cleanEmail,
        userDisplayName: name.isNotEmpty ? name : (user?.displayName ?? cleanEmail.split('@').first),
        userPhotoUrl: user?.photoURL,
        isSignedIn: true,
        lastActiveTime: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Forgot Password flow via Firebase Auth
  Future<void> sendPasswordReset(String email) async {
    await _recoveryService.sendPasswordResetEmail(email.trim());
  }

  /// Sign Out: clears Firebase session and returns to login screen
  Future<void> signOut() async {
    await _recoveryService.signOut();
    await _authService.clearSession();

    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      isSignedIn: false,
      userEmail: null,
      userDisplayName: null,
      userPhotoUrl: null,
    );
  }

  /// Continue as Guest / Offline Vault Access
  void continueOffline() {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      userEmail: 'guest.vault@local',
      userDisplayName: 'Local Vault User',
      isSignedIn: false,
      lastActiveTime: DateTime.now(),
    );
  }

  Future<bool> unlockApp() async {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      unlockedCategoryIds: {'cat_work', 'cat_personal', 'cat_business'},
      lastActiveTime: DateTime.now(),
    );
    return true;
  }

  /// Toggles screen capture protection dynamically.
  Future<void> toggleScreenCaptureProtection(bool enabled) async {
    await _keyStorageService.setScreenCaptureProtectionEnabled(enabled);
    await ScreenProtectionService.setProtection(enabled);
    state = state.copyWith(isScreenCaptureProtectionEnabled: enabled);
  }

  /// Returns master vault key for the optional offline download.
  Future<String> exportVaultKeyForOfflineBackup() async {
    return await _keyStorageService.getOrCreateMasterKey();
  }

  Future<bool> unlockCategory(String categoryId) async {
    final updatedSet = Set<String>.from(state.unlockedCategoryIds)..add(categoryId);
    state = state.copyWith(
      unlockedCategoryIds: updatedSet,
      lastActiveTime: DateTime.now(),
    );
    return true;
  }

  void recordActivity() {
    state = state.copyWith(lastActiveTime: DateTime.now());
  }

  void lockApp() {
    state = state.copyWith(
      status: AuthStatus.locked,
      unlockedCategoryIds: {},
    );
  }

  void handleAppPaused() {
    if (state.autoLockTimeout == 'immediate') {
      lockApp();
    }
  }

  void checkInactivityTimeout() {
    if (state.status != AuthStatus.authenticated) return;

    final now = DateTime.now();
    final elapsed = now.difference(state.lastActiveTime);

    if (state.autoLockTimeout == 'immediate' && elapsed.inSeconds > 0) {
      lockApp();
    } else if (state.autoLockTimeout == '1min' && elapsed.inMinutes >= 1) {
      lockApp();
    } else if (state.autoLockTimeout == '5min' && elapsed.inMinutes >= 5) {
      lockApp();
    }
  }

  Future<void> updateAutoLockTimeout(String timeout) async {
    await _keyStorageService.setAutoLockTimeout(timeout);
    state = state.copyWith(autoLockTimeout: timeout);
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// Categories Provider
class CategoriesNotifier extends AsyncNotifier<List<CategoryEntity>> {
  @override
  Future<List<CategoryEntity>> build() async {
    final repository = ref.watch(vaultRepositoryProvider);
    return await repository.getCategories();
  }

  Future<void> loadCategories() async {
    ref.invalidateSelf();
  }

  Future<void> addCategory(String name, bool isLocked) async {
    final repository = ref.read(vaultRepositoryProvider);
    final existing = state.value ?? [];
    final newCategory = CategoryEntity(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      isLocked: isLocked,
      isDefault: false,
      sortOrder: existing.length,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    await repository.saveCategory(newCategory);
    ref.invalidateSelf();
  }

  Future<void> renameCategory(String id, String newName) async {
    final repository = ref.read(vaultRepositoryProvider);
    final cat = await repository.getCategoryById(id);
    if (cat != null) {
      final updated = cat.copyWith(
        name: newName.trim(),
        updatedAt: DateTime.now().toUtc(),
      );
      await repository.saveCategory(updated);
      ref.invalidateSelf();
    }
  }

  Future<void> toggleCategoryLock(String id, bool isLocked) async {
    final repository = ref.read(vaultRepositoryProvider);
    final cat = await repository.getCategoryById(id);
    if (cat != null) {
      final updated = cat.copyWith(
        isLocked: isLocked,
        updatedAt: DateTime.now().toUtc(),
      );
      await repository.saveCategory(updated);
      ref.invalidateSelf();
    }
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final repository = ref.read(vaultRepositoryProvider);
    final list = List<CategoryEntity>.from(state.value ?? []);
    if (oldIndex < list.length && newIndex < list.length) {
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      state = AsyncValue.data(list);
      await repository.reorderCategories(list.map((c) => c.id).toList());
      ref.invalidateSelf();
    }
  }

  Future<void> deleteCategory(String id) async {
    final repository = ref.read(vaultRepositoryProvider);
    await repository.deleteCategory(id);
    ref.invalidateSelf();
  }
}

final categoriesProvider = AsyncNotifierProvider<CategoriesNotifier, List<CategoryEntity>>(
  CategoriesNotifier.new,
);

// Selected Category Provider (Defaults to 'cat_work')
class SelectedCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'cat_work';

  void selectCategory(String categoryId) {
    state = categoryId;
  }
}

final selectedCategoryProvider = NotifierProvider<SelectedCategoryNotifier, String>(
  SelectedCategoryNotifier.new,
);

// Credentials for Selected Category
class CredentialsNotifier extends AsyncNotifier<List<CredentialEntity>> {
  @override
  Future<List<CredentialEntity>> build() async {
    final repository = ref.watch(vaultRepositoryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    return await repository.getCredentialsByCategory(selectedCategory);
  }

  Future<void> loadForCategory([String? categoryId]) async {
    ref.invalidateSelf();
  }

  Future<void> saveCredential(CredentialEntity credential) async {
    final repository = ref.read(vaultRepositoryProvider);
    await repository.saveCredential(credential);
    ref.invalidateSelf();
  }

  Future<void> deleteCredential(String id) async {
    final repository = ref.read(vaultRepositoryProvider);
    await repository.deleteCredential(id);
    ref.invalidateSelf();
  }
}

final credentialsProvider = AsyncNotifierProvider<CredentialsNotifier, List<CredentialEntity>>(
  CredentialsNotifier.new,
);

// Search Query Provider
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// Filtered Credentials
final filteredCredentialsProvider = Provider<List<CredentialEntity>>((ref) {
  final credentialsAsync = ref.watch(credentialsProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return credentialsAsync.when(
    data: (list) {
      if (query.isEmpty) return list;
      return list.where((item) {
        final emailMatches = item.email.toLowerCase().contains(query);
        final labelMatches = item.label != null && item.label!.toLowerCase().contains(query);
        return emailMatches || labelMatches;
      }).toList();
    },
    loading: () => [],
    error: (e, st) => [],
  );
});
