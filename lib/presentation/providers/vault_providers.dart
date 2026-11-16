import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/biometric_service.dart';
import '../../core/security/key_storage_service.dart';
import '../../data/datasources/export_import_service.dart';
import '../../data/datasources/local_database.dart';
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

  const AuthState({
    required this.status,
    required this.autoLockTimeout,
    required this.unlockedCategoryIds,
    required this.lastActiveTime,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? autoLockTimeout,
    Set<String>? unlockedCategoryIds,
    DateTime? lastActiveTime,
  }) {
    return AuthState(
      status: status ?? this.status,
      autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
      unlockedCategoryIds: unlockedCategoryIds ?? this.unlockedCategoryIds,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final BiometricService _biometricService;
  late final KeyStorageService _keyStorageService;

  @override
  AuthState build() {
    _biometricService = ref.read(biometricServiceProvider);
    _keyStorageService = ref.read(keyStorageServiceProvider);

    // Initial check
    Future.microtask(() => initialize());

    return AuthState(
      status: AuthStatus.initial,
      autoLockTimeout: '1min',
      unlockedCategoryIds: {},
      lastActiveTime: DateTime.now(),
    );
  }

  Future<void> initialize() async {
    final timeout = await _keyStorageService.getAutoLockTimeout();
    final isSecured = await _biometricService.isDeviceSecured();

    if (!isSecured) {
      state = state.copyWith(
        status: AuthStatus.deviceSecurityMissing,
        autoLockTimeout: timeout,
      );
      return;
    }

    state = state.copyWith(
      status: AuthStatus.locked,
      autoLockTimeout: timeout,
      unlockedCategoryIds: {},
    );

    // Prompt initial unlock
    await unlockApp();
  }

  Future<bool> unlockApp() async {
    final isSecured = await _biometricService.isDeviceSecured();
    if (!isSecured) {
      state = state.copyWith(status: AuthStatus.deviceSecurityMissing);
      return false;
    }

    final success = await _biometricService.authenticate(
      localizedReason: 'Unlock MyMail Vault to access your credentials',
    );

    if (success) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        unlockedCategoryIds: {'cat_work'}, // Work is the main entry point
        lastActiveTime: DateTime.now(),
      );
      return true;
    } else {
      state = state.copyWith(status: AuthStatus.locked);
      return false;
    }
  }

  Future<bool> unlockCategory(String categoryId) async {
    if (state.unlockedCategoryIds.contains(categoryId)) {
      recordActivity();
      return true;
    }

    final success = await _biometricService.authenticate(
      localizedReason: 'Authenticate to access this locked category',
    );

    if (success) {
      final updatedSet = Set<String>.from(state.unlockedCategoryIds)..add(categoryId);
      state = state.copyWith(
        unlockedCategoryIds: updatedSet,
        lastActiveTime: DateTime.now(),
      );
      return true;
    }
    return false;
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
class CategoriesNotifier extends Notifier<AsyncValue<List<CategoryEntity>>> {
  late final VaultRepository _repository;

  @override
  AsyncValue<List<CategoryEntity>> build() {
    _repository = ref.read(vaultRepositoryProvider);
    Future.microtask(() => loadCategories());
    return const AsyncValue.loading();
  }

  Future<void> loadCategories() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => await _repository.getCategories());
  }

  Future<void> addCategory(String name, bool isLocked) async {
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

    await _repository.saveCategory(newCategory);
    await loadCategories();
  }

  Future<void> renameCategory(String id, String newName) async {
    final cat = await _repository.getCategoryById(id);
    if (cat != null) {
      final updated = cat.copyWith(
        name: newName.trim(),
        updatedAt: DateTime.now().toUtc(),
      );
      await _repository.saveCategory(updated);
      await loadCategories();
    }
  }

  Future<void> toggleCategoryLock(String id, bool isLocked) async {
    final cat = await _repository.getCategoryById(id);
    if (cat != null) {
      final updated = cat.copyWith(
        isLocked: isLocked,
        updatedAt: DateTime.now().toUtc(),
      );
      await _repository.saveCategory(updated);
      await loadCategories();
    }
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final list = List<CategoryEntity>.from(state.value ?? []);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    state = AsyncValue.data(list);
    await _repository.reorderCategories(list.map((c) => c.id).toList());
    await loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await _repository.deleteCategory(id);
    await loadCategories();
  }
}

final categoriesProvider = NotifierProvider<CategoriesNotifier, AsyncValue<List<CategoryEntity>>>(
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
class CredentialsNotifier extends Notifier<AsyncValue<List<CredentialEntity>>> {
  late final VaultRepository _repository;

  @override
  AsyncValue<List<CredentialEntity>> build() {
    _repository = ref.read(vaultRepositoryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    Future.microtask(() => loadForCategory(selectedCategory));
    return const AsyncValue.loading();
  }

  Future<void> loadForCategory(String categoryId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => await _repository.getCredentialsByCategory(categoryId));
  }

  Future<void> saveCredential(CredentialEntity credential) async {
    await _repository.saveCredential(credential);
    final selectedCategory = ref.read(selectedCategoryProvider);
    await loadForCategory(selectedCategory);
  }

  Future<void> deleteCredential(String id) async {
    await _repository.deleteCredential(id);
    final selectedCategory = ref.read(selectedCategoryProvider);
    await loadForCategory(selectedCategory);
  }
}

final credentialsProvider = NotifierProvider<CredentialsNotifier, AsyncValue<List<CredentialEntity>>>(
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
