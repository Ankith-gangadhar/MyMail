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

    // Check if an authenticated MyMail session is stored locally
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

    // Otherwise unauthenticated
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

  /// Sign In with Google for MyMail
  Future<void> signInWithGoogle() async {
    final session = await _authService.signInWithGoogle();
    state = state.copyWith(
      status: AuthStatus.authenticated,
      userEmail: session.email,
      userDisplayName: session.displayName ?? 'Ankith Gangadhar',
      userPhotoUrl: session.avatarUrl,
      isSignedIn: true,
      lastActiveTime: DateTime.now(),
    );
  }

  /// Sign In with Email & Password (verified against stored credentials)
  Future<void> signInWithEmail(String email, String password) async {
    final session = await _authService.signInWithPassword(
      email: email,
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
  }

  /// Create Account with Email & Password (stored in MyMail secure vault)
  Future<void> signUpWithEmail(String email, String password, String name) async {
    final session = await _authService.signUp(
      email: email,
      password: password,
      name: name,
    );

    state = state.copyWith(
      status: AuthStatus.authenticated,
      userEmail: session.email,
      userDisplayName: session.displayName ?? (name.isNotEmpty ? name : session.email.split('@').first),
      userPhotoUrl: session.avatarUrl,
      isSignedIn: true,
      lastActiveTime: DateTime.now(),
    );
  }

  /// Forgot Password flow
  Future<void> sendPasswordReset(String email) async {
    await _authService.sendPasswordReset(email);
  }

  /// Sign Out: clears session and returns to login screen
  Future<void> signOut() async {
    await _authService.clearSession();
    try {
      await _recoveryService.signOut();
    } catch (_) {}

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
