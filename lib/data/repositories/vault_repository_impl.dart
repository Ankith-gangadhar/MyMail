import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/crypto/aes_gcm_service.dart';
import '../../core/security/key_storage_service.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/credential_entity.dart';
import '../../domain/repositories/vault_repository.dart';
import '../datasources/local_database.dart';

class VaultRepositoryImpl implements VaultRepository {
  final LocalDatabase _localDb;
  final AesGcmService _aesGcmService;
  final KeyStorageService _keyStorageService;

  // In-memory data store for Web preview & immediate offline testing
  final List<CategoryEntity> _memoryCategories = [];
  final List<CredentialEntity> _memoryCredentials = [];
  bool _memoryInitialized = false;

  VaultRepositoryImpl({
    LocalDatabase? localDb,
    AesGcmService? aesGcmService,
    KeyStorageService? keyStorageService,
  })  : _localDb = localDb ?? LocalDatabase(),
        _aesGcmService = aesGcmService ?? AesGcmService(),
        _keyStorageService = keyStorageService ?? KeyStorageService() {
    _initMemoryData();
  }

  void _initMemoryData() {
    if (_memoryInitialized) return;
    _memoryInitialized = true;

    final now = DateTime.now().toUtc();
    _memoryCategories.addAll([
      CategoryEntity(
        id: 'cat_work',
        name: 'Work',
        isLocked: true,
        isDefault: true,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
      CategoryEntity(
        id: 'cat_personal',
        name: 'Personal',
        isLocked: true,
        isDefault: true,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CategoryEntity(
        id: 'cat_business',
        name: 'Business',
        isLocked: false,
        isDefault: false,
        sortOrder: 2,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    _memoryCredentials.addAll([
      CredentialEntity(
        id: 'cred_work_1',
        categoryId: 'cat_work',
        email: 'ankith.work@gmail.com',
        password: 'WorkSecurity#2026!',
        label: 'Google Workspace',
        createdAt: now,
        updatedAt: now,
      ),
      CredentialEntity(
        id: 'cred_work_2',
        categoryId: 'cat_work',
        email: 'devops.team@github.com',
        password: 'GhEnterpriseToken!99',
        label: 'GitHub Dev',
        createdAt: now,
        updatedAt: now,
      ),
      CredentialEntity(
        id: 'cred_personal_1',
        categoryId: 'cat_personal',
        email: 'ankith.gangadhar@gmail.com',
        password: 'PersonalSecret#882',
        label: 'Primary Gmail',
        createdAt: now,
        updatedAt: now,
      ),
      CredentialEntity(
        id: 'cred_personal_2',
        categoryId: 'cat_personal',
        email: 'stream.user@gmail.com',
        password: 'StreamPass!2026',
        label: 'Netflix & Spotify',
        createdAt: now,
        updatedAt: now,
      ),
      CredentialEntity(
        id: 'cred_business_1',
        categoryId: 'cat_business',
        email: 'founder@mybusiness.com',
        password: 'BizVenture#771',
        label: 'Business Portal',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  Future<String> _getKey() => _keyStorageService.getOrCreateMasterKey();

  @override
  Future<List<CategoryEntity>> getCategories() async {
    if (kIsWeb) {
      return _memoryCategories.where((c) => !c.isDeleted).toList();
    }
    try {
      final db = await _localDb.database;
      final rows = await db.query(
        'categories',
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'sort_order ASC, created_at ASC',
      );

      if (rows.isNotEmpty) {
        return rows.map((r) => CategoryEntity.fromMap(r)).toList();
      }
      return _memoryCategories.where((c) => !c.isDeleted).toList();
    } catch (_) {
      return _memoryCategories.where((c) => !c.isDeleted).toList();
    }
  }

  @override
  Future<CategoryEntity?> getCategoryById(String id) async {
    if (kIsWeb) {
      try {
        return _memoryCategories.firstWhere(
          (c) => c.id == id && !c.isDeleted,
        );
      } catch (_) {
        return null;
      }
    }
    try {
      final db = await _localDb.database;
      final rows = await db.query(
        'categories',
        where: 'id = ? AND is_deleted = ?',
        whereArgs: [id, 0],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return CategoryEntity.fromMap(rows.first);
      }
      try {
        return _memoryCategories.firstWhere((c) => c.id == id);
      } catch (_) {
        return null;
      }
    } catch (_) {
      try {
        return _memoryCategories.firstWhere((c) => c.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<void> saveCategory(CategoryEntity category) async {
    _memoryCategories.removeWhere((c) => c.id == category.id);
    _memoryCategories.add(category);

    if (!kIsWeb) {
      try {
        final db = await _localDb.database;
        final map = category.toMap();
        await db.insert(
          'categories',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    final idx = _memoryCategories.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _memoryCategories[idx] = _memoryCategories[idx].copyWith(isDeleted: true);
    }
    for (int i = 0; i < _memoryCredentials.length; i++) {
      if (_memoryCredentials[i].categoryId == id) {
        _memoryCredentials[i] = _memoryCredentials[i].copyWith(isDeleted: true);
      }
    }

    if (!kIsWeb) {
      try {
        final db = await _localDb.database;
        final now = DateTime.now().toUtc().toIso8601String();
        await db.transaction((txn) async {
          await txn.update(
            'categories',
            {'is_deleted': 1, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [id],
          );
          await txn.update(
            'credentials',
            {'is_deleted': 1, 'updated_at': now},
            where: 'category_id = ?',
            whereArgs: [id],
          );
        });
      } catch (_) {}
    }
  }

  @override
  Future<void> reorderCategories(List<String> categoryIds) async {
    for (int i = 0; i < categoryIds.length; i++) {
      final idx = _memoryCategories.indexWhere((c) => c.id == categoryIds[i]);
      if (idx != -1) {
        _memoryCategories[idx] = _memoryCategories[idx].copyWith(sortOrder: i);
      }
    }
    _memoryCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (!kIsWeb) {
      try {
        final db = await _localDb.database;
        final now = DateTime.now().toUtc().toIso8601String();
        await db.transaction((txn) async {
          for (int i = 0; i < categoryIds.length; i++) {
            await txn.update(
              'categories',
              {'sort_order': i, 'updated_at': now},
              where: 'id = ?',
              whereArgs: [categoryIds[i]],
            );
          }
        });
      } catch (_) {}
    }
  }

  @override
  Future<List<CredentialEntity>> getCredentialsByCategory(String categoryId) async {
    if (kIsWeb) {
      return _memoryCredentials
          .where((c) => c.categoryId == categoryId && !c.isDeleted)
          .toList();
    }
    try {
      final db = await _localDb.database;
      final key = await _getKey();

      final rows = await db.query(
        'credentials',
        where: 'category_id = ? AND is_deleted = ?',
        whereArgs: [categoryId, 0],
        orderBy: 'updated_at DESC',
      );

      final List<CredentialEntity> list = [];
      for (final row in rows) {
        try {
          final email = await _aesGcmService.decrypt(
            encryptedData: EncryptedData(
              ciphertextBase64: row['email_cipher'] as String,
              nonceBase64: row['email_nonce'] as String,
              macBase64: row['email_mac'] as String,
            ),
            keyBase64: key,
          );

          final password = await _aesGcmService.decrypt(
            encryptedData: EncryptedData(
              ciphertextBase64: row['password_cipher'] as String,
              nonceBase64: row['password_nonce'] as String,
              macBase64: row['password_mac'] as String,
            ),
            keyBase64: key,
          );

          String? label;
          if (row['label_cipher'] != null &&
              row['label_nonce'] != null &&
              row['label_mac'] != null) {
            label = await _aesGcmService.decrypt(
              encryptedData: EncryptedData(
                ciphertextBase64: row['label_cipher'] as String,
                nonceBase64: row['label_nonce'] as String,
                macBase64: row['label_mac'] as String,
              ),
              keyBase64: key,
            );
          }

          list.add(CredentialEntity(
            id: row['id'] as String,
            categoryId: row['category_id'] as String,
            email: email,
            password: password,
            label: label,
            createdAt: DateTime.parse(row['created_at'] as String),
            updatedAt: DateTime.parse(row['updated_at'] as String),
            isDeleted: (row['is_deleted'] as int) == 1,
          ));
        } catch (_) {}
      }
      if (list.isNotEmpty) return list;
      return _memoryCredentials
          .where((c) => c.categoryId == categoryId && !c.isDeleted)
          .toList();
    } catch (_) {
      return _memoryCredentials
          .where((c) => c.categoryId == categoryId && !c.isDeleted)
          .toList();
    }
  }

  @override
  Future<List<CredentialEntity>> getAllCredentials() async {
    if (kIsWeb) {
      return _memoryCredentials.where((c) => !c.isDeleted).toList();
    }
    try {
      final db = await _localDb.database;
      final key = await _getKey();

      final rows = await db.query(
        'credentials',
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'updated_at DESC',
      );

      final List<CredentialEntity> list = [];
      for (final row in rows) {
        try {
          final email = await _aesGcmService.decrypt(
            encryptedData: EncryptedData(
              ciphertextBase64: row['email_cipher'] as String,
              nonceBase64: row['email_nonce'] as String,
              macBase64: row['email_mac'] as String,
            ),
            keyBase64: key,
          );

          final password = await _aesGcmService.decrypt(
            encryptedData: EncryptedData(
              ciphertextBase64: row['password_cipher'] as String,
              nonceBase64: row['password_nonce'] as String,
              macBase64: row['password_mac'] as String,
            ),
            keyBase64: key,
          );

          String? label;
          if (row['label_cipher'] != null &&
              row['label_nonce'] != null &&
              row['label_mac'] != null) {
            label = await _aesGcmService.decrypt(
              encryptedData: EncryptedData(
                ciphertextBase64: row['label_cipher'] as String,
                nonceBase64: row['label_nonce'] as String,
                macBase64: row['label_mac'] as String,
              ),
              keyBase64: key,
            );
          }

          list.add(CredentialEntity(
            id: row['id'] as String,
            categoryId: row['category_id'] as String,
            email: email,
            password: password,
            label: label,
            createdAt: DateTime.parse(row['created_at'] as String),
            updatedAt: DateTime.parse(row['updated_at'] as String),
            isDeleted: (row['is_deleted'] as int) == 1,
          ));
        } catch (_) {}
      }
      if (list.isNotEmpty) return list;
      return _memoryCredentials.where((c) => !c.isDeleted).toList();
    } catch (_) {
      return _memoryCredentials.where((c) => !c.isDeleted).toList();
    }
  }

  @override
  Future<void> saveCredential(CredentialEntity credential) async {
    _memoryCredentials.removeWhere((c) => c.id == credential.id);
    _memoryCredentials.insert(0, credential);

    if (!kIsWeb) {
      try {
        final db = await _localDb.database;
        final key = await _getKey();

        final emailEnc = await _aesGcmService.encrypt(
          plainText: credential.email,
          keyBase64: key,
        );

        final passwordEnc = await _aesGcmService.encrypt(
          plainText: credential.password,
          keyBase64: key,
        );

        EncryptedData? labelEnc;
        if (credential.label != null && credential.label!.isNotEmpty) {
          labelEnc = await _aesGcmService.encrypt(
            plainText: credential.label!,
            keyBase64: key,
          );
        }

        final row = {
          'id': credential.id,
          'category_id': credential.categoryId,
          'email_cipher': emailEnc.ciphertextBase64,
          'email_nonce': emailEnc.nonceBase64,
          'email_mac': emailEnc.macBase64,
          'password_cipher': passwordEnc.ciphertextBase64,
          'password_nonce': passwordEnc.nonceBase64,
          'password_mac': passwordEnc.macBase64,
          'label_cipher': labelEnc?.ciphertextBase64,
          'label_nonce': labelEnc?.nonceBase64,
          'label_mac': labelEnc?.macBase64,
          'created_at': credential.createdAt.toIso8601String(),
          'updated_at': credential.updatedAt.toIso8601String(),
          'is_deleted': credential.isDeleted ? 1 : 0,
        };

        await db.insert(
          'credentials',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> deleteCredential(String id) async {
    final idx = _memoryCredentials.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _memoryCredentials[idx] = _memoryCredentials[idx].copyWith(isDeleted: true);
    }

    if (!kIsWeb) {
      try {
        final db = await _localDb.database;
        final now = DateTime.now().toUtc().toIso8601String();
        await db.update(
          'credentials',
          {'is_deleted': 1, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> restoreAll({
    required List<CategoryEntity> categories,
    required List<CredentialEntity> credentials,
    required bool replace,
  }) async {
    if (replace) {
      _memoryCategories.clear();
      _memoryCredentials.clear();
    }
    for (final cat in categories) {
      _memoryCategories.removeWhere((c) => c.id == cat.id);
      _memoryCategories.add(cat);
    }
    for (final cred in credentials) {
      _memoryCredentials.removeWhere((c) => c.id == cred.id);
      _memoryCredentials.add(cred);
    }

    if (!kIsWeb) {
      try {
        final db = await _localDb.database;
        await db.transaction((txn) async {
          if (replace) {
            await txn.delete('credentials');
            await txn.delete('categories');
          }

          for (final cat in categories) {
            await txn.insert(
              'categories',
              cat.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });

        for (final cred in credentials) {
          await saveCredential(cred);
        }
      } catch (_) {}
    }
  }
}