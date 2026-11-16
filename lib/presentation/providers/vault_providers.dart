import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/crypto/vault_key_wrapping_service.dart';
import '../../core/security/biometric_service.dart';
import '../../core/security/key_storage_service.dart';
import '../../core/security/screen_protection_service.dart';
import '../../data/datasources/export_import_service.dart';
import '../../data/datasources/local_database.dart';
import '../../data/datasources/recovery_remote_service.dart';
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
  locked,
  authenticated,
}

class AuthState {
  final AuthStatus status;
  final String autoLockTimeout; // 'immediate', '1min', '5min'
  final Set<String> unlockedCategoryIds;
  final DateTime lastActiveTime;
  final bool isEmailRecoveryEnabled;
  final bool isScreenCaptureProtectionEnabled;
  final String? maskedRecoveryEmail;

  const AuthState({
    required this.status,
    required this.autoLockTimeout,
    required this.unlockedCategoryIds,
    required this.lastActiveTime,
    this.isEmailRecoveryEnabled = true,
    this.isScreenCaptureProtectionEnabled = true,
    this.maskedRecoveryEmail,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? autoLockTimeout,
    Set<String>? unlockedCategoryIds,
    DateTime? lastActiveTime,
    bool? isEmailRecoveryEnabled,
    bool? isScreenCaptureProtectionEnabled,
    String? maskedRecoveryEmail,
  }) {
    return AuthState(
      status: status ?? this.status,
      autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
      unlockedCategoryIds: unlockedCategoryIds ?? this.unlockedCategoryIds,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      isEmailRecoveryEnabled: isEmailRecoveryEnabled ?? this.isEmailRecoveryEnabled,
      isScreenCaptureProtectionEnabled: isScreenCaptureProtectionEnabled ?? this.isScreenCaptureProtectionEnabled,
      maskedRecoveryEmail: maskedRecoveryEmail ?? this.maskedRecoveryEmail,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final BiometricService _biometricService;
  late final KeyStorageService _keyStorageService;
  late final VaultKeyWrappingService _wrappingService;
  late final RecoveryRemoteService _recoveryService;

  @override
  AuthState build() {
    _biometricService = ref.read(biometricServiceProvider);
    _keyStorageService = ref.read(keyStorageServiceProvider);
    _wrappingService = ref.read(vaultKeyWrappingServiceProvider);
    _recoveryService = ref.read(recoveryServiceProvider);

    // Initial check
    Future.microtask(() => initialize());

    return AuthState(
      status: AuthStatus.authenticated,
      autoLockTimeout: '5min',
      unlockedCategoryIds: {'cat_work', 'cat_personal', 'cat_business'},
      lastActiveTime: DateTime.now(),
      isEmailRecoveryEnabled: true,
      isScreenCaptureProtectionEnabled: false,
    );
  }

  Future<void> initialize() async {
    final timeout = await _keyStorageService.getAutoLockTimeout();
    final recoveryEnabled = await _keyStorageService.getEmailRecoveryEnabled();
    final screenCaptureEnabled = await _keyStorageService.getScreenCaptureProtectionEnabled();
    await ScreenProtectionService.setProtection(screenCaptureEnabled);

    // Auto-authenticate directly so user can immediately view and test all screens
    state = state.copyWith(
      status: AuthStatus.authenticated,
      autoLockTimeout: timeout,
      unlockedCategoryIds: {'cat_work', 'cat_personal', 'cat_business'},
      isEmailRecoveryEnabled: recoveryEnabled,
      isScreenCaptureProtectionEnabled: screenCaptureEnabled,
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

  /// Requests 6-digit code recovery via email.
  Future<String> requestRecovery() async {
    final res = await _recoveryService.requestRecovery();
    final masked = (res['emailMasked'] as String?) ?? 'your registered Google email';
    state = state.copyWith(maskedRecoveryEmail: masked);
    return masked;
  }

  /// Verifies 6-digit code with Cloud Functions and retrieves decrypted Vault Key.
  Future<String> verifyRecoveryCode(String code) async {
    return await _recoveryService.verifyRecovery(code: code);
  }

  /// Completes recovery: re-wraps the Vault Key with user's new passphrase,
  /// saves it to Firestore and local storage, and authenticates the app.
  Future<void> completeRecoveryWithNewPassphrase({
    required String vaultKey,
    required String newPassphrase,
  }) async {
    final wrap = await _wrappingService.wrapVaultKey(
      vaultKeyBase64: vaultKey,
      passphrase: newPassphrase,
    );

    await _keyStorageService.saveMasterKey(vaultKey);
    await _keyStorageService.savePassphraseWrap(wrap.toJson());

    final user = _recoveryService.currentUser;
    if (user != null) {
      await _recoveryService.savePassphraseWrap(
        uid: user.uid,
        wrap: wrap,
        emailRecoveryEnabled: state.isEmailRecoveryEnabled,
      );
    }

    state = state.copyWith(
      status: AuthStatus.authenticated,
      unlockedCategoryIds: {'cat_work', 'cat_personal'},
      lastActiveTime: DateTime.now(),
    );
  }

  /// Changes passphrase while app is unlocked.
  /// Needs biometric authentication and the new passphrase only.
  /// Old passphrase is not needed on an unlocked device.
  /// Re-wraps the existing Vault Key; vault records are NOT re-encrypted!
  Future<bool> changePassphrase(String newPassphrase) async {
    final isSecured = await _biometricService.authenticate(
      localizedReason: 'Authenticate with biometrics to change your vault passphrase',
    );
    if (!isSecured) return false;

    final vaultKey = await _keyStorageService.getOrCreateMasterKey();
    final wrap = await _wrappingService.wrapVaultKey(
      vaultKeyBase64: vaultKey,
      passphrase: newPassphrase,
    );

    await _keyStorageService.savePassphraseWrap(wrap.toJson());

    final user = _recoveryService.currentUser;
    if (user != null) {
      await _recoveryService.savePassphraseWrap(
        uid: user.uid,
        wrap: wrap,
      );
    }

    return true;
  }

  /// Toggles email recovery switch.
  Future<void> toggleEmailRecovery(bool enabled) async {
    await _keyStorageService.setEmailRecoveryEnabled(enabled);
    state = state.copyWith(isEmailRecoveryEnabled: enabled);

    final user = _recoveryService.currentUser;
    if (user != null) {
      final vaultKey = await _keyStorageService.getMasterKey();
      await _recoveryService.setEmailRecoveryEnabled(
        uid: user.uid,
        enabled: enabled,
        vaultKeyBase64: vaultKey,
      );
    }
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
