import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Active user identity for strict session/tenant data isolation
  String _activeUserId = 'guest';

  // In-memory data store strictly scoped per user session (e.g., userEmail or UID)
  final Map<String, List<CategoryEntity>> _userCategories = {};
  final Map<String, List<CredentialEntity>> _userCredentials = {};

  VaultRepositoryImpl({
    LocalDatabase? localDb,
    AesGcmService? aesGcmService,
    KeyStorageService? keyStorageService,
  })  : _localDb = localDb ?? LocalDatabase(),
        _aesGcmService = aesGcmService ?? AesGcmService(),
        _keyStorageService = keyStorageService ?? KeyStorageService();

  @override
  void setActiveUser(String? userId) {
    final clean = userId?.trim().toLowerCase();
    _activeUserId = (clean != null && clean.isNotEmpty) ? clean : 'guest';
  }

  @override
  void clearActiveSession() {
    _activeUserId = 'guest';
    _userCategories.clear();
    _userCredentials.clear();
  }

  String? get _firebaseUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  List<CategoryEntity> _getDefaultCategories() {
    final now = DateTime.now().toUtc();
    return [
      CategoryEntity(
        id: 'cat_work',
        name: 'Work',
        isLocked: false,
        isDefault: true,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
      CategoryEntity(
        id: 'cat_personal',
        name: 'Personal',
        isLocked: false,
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
    ];
  }

  List<CredentialEntity> _getCredentialsForActiveUser() {
    return _userCredentials.putIfAbsent(_activeUserId, () => []);
  }

  Future<String> _getKey() => _keyStorageService.getOrCreateMasterKey();

  @override
  Future<List<CategoryEntity>> getCategories() async {
    final uid = _firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('categories')
            .where('is_deleted', isEqualTo: 0)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs
              .map((d) => CategoryEntity.fromMap(d.data()))
              .toList();
          list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          _userCategories[_activeUserId] = list;
          return list;
        } else {
          // Initialize default categories for this user in Firestore
          final defaults = _getDefaultCategories();
          for (final cat in defaults) {
            await _firestore
                .collection('users')
                .doc(uid)
                .collection('categories')
                .doc(cat.id)
                .set(cat.toMap(), SetOptions(merge: true));
          }
          _userCategories[_activeUserId] = defaults;
          return defaults;
        }
      } catch (e) {
        debugPrint('Firestore getCategories note: $e');
      }
    }

    if (kIsWeb) {
      final list = _userCategories.putIfAbsent(_activeUserId, () => _getDefaultCategories());
      return list.where((c) => !c.isDeleted).toList();
    }

    try {
      final db = await _localDb.database;
      final rows = await db.query(
        'categories',
        where: 'user_id = ? AND is_deleted = ?',
        whereArgs: [_activeUserId, 0],
        orderBy: 'sort_order ASC, created_at ASC',
      );

      if (rows.isNotEmpty) {
        final list = rows.map((r) => CategoryEntity.fromMap(r)).toList();
        _userCategories[_activeUserId] = list;
        return list;
      }

      // If empty for this user, seed default categories for this user
      final defaults = _getDefaultCategories();
      for (final cat in defaults) {
        final map = cat.toMap();
        map['user_id'] = _activeUserId;
        await db.insert('categories', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      _userCategories[_activeUserId] = defaults;
      return defaults;
    } catch (_) {
      final list = _userCategories.putIfAbsent(_activeUserId, () => _getDefaultCategories());
      return list.where((c) => !c.isDeleted).toList();
    }
  }

  @override
  Future<CategoryEntity?> getCategoryById(String id) async {
    final categories = await getCategories();
    try {
      return categories.firstWhere((c) => c.id == id && !c.isDeleted);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveCategory(CategoryEntity category) async {
    final categories = _userCategories.putIfAbsent(_activeUserId, () => _getDefaultCategories());
    categories.removeWhere((c) => c.id == category.id);
    categories.add(category);

    final uid = _firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('categories')
            .doc(category.id)
            .set(category.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore saveCategory note: $e');
      }
    }

    if (!kIsWeb) {
      try {
        final db = await _localDb.database;
        final map = category.toMap();
        map['user_id'] = _activeUserId;
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
    final categories = _userCategories.putIfAbsent(_activeUserId, () => _getDefaultCategories());
    final idx = categories.indexWhere((c) => c.id == id);
    if (idx != -1) {
      categories[idx] = categories[idx].copyWith(isDeleted: true);
    }

    final userCreds = _getCredentialsForActiveUser();
    for (int i = 0; i < userCreds.length; i++) {
      if (userCreds[i].categoryId == id) {
        userCreds[i] = userCreds[i].copyWith(isDeleted: true);
      }
    }

    final uid = _firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('categories')
            .doc(id)
            .update({
          'is_deleted': 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Firestore deleteCategory note: $e');
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
            where: 'user_id = ? AND id = ?',
            whereArgs: [_activeUserId, id],
          );
          await txn.update(
            'credentials',
            {'is_deleted': 1, 'updated_at': now},
            where: 'user_id = ? AND category_id = ?',
            whereArgs: [_activeUserId, id],
          );
        });
      } catch (_) {}
    }
  }

  @override
  Future<void> reorderCategories(List<String> categoryIds) async {
    final categories = _userCategories.putIfAbsent(_activeUserId, () => _getDefaultCategories());
    for (int i = 0; i < categoryIds.length; i++) {
      final idx = categories.indexWhere((c) => c.id == categoryIds[i]);
      if (idx != -1) {
        categories[idx] = categories[idx].copyWith(sortOrder: i);
      }
    }
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final uid = _firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      try {
        for (int i = 0; i < categoryIds.length; i++) {
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('categories')
              .doc(categoryIds[i])
              .update({'sort_order': i});
        }
      } catch (e) {
        debugPrint('Firestore reorderCategories note: $e');
      }
    }

    if (!kIsWeb) {
      try {
        final db = await _localDb.database;
        final now = DateTime.now().toUtc().toIso8601String();
        await db.transaction((txn) async {
          for (int i = 0; i < categoryIds.length; i++) {
            await txn.update(
              'categories',
              {'sort_order': i, 'updated_at': now},
              where: 'user_id = ? AND id = ?',
              whereArgs: [_activeUserId, categoryIds[i]],
            );
          }
        });
      } catch (_) {}
    }
  }

  @override
  Future<List<CredentialEntity>> getCredentialsByCategory(String categoryId) async {
    final uid = _firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('credentials')
            .where('categoryId', isEqualTo: categoryId)
            .where('isDeleted', isEqualTo: false)
            .get();

        final list = snapshot.docs
            .map((d) => CredentialEntity.fromJson(d.data()))
            .toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final userCreds = _getCredentialsForActiveUser();
        userCreds.removeWhere((c) => c.categoryId == categoryId);
        userCreds.addAll(list);

        return list;
      } catch (e) {
        debugPrint('Firestore getCredentialsByCategory note: $e');
      }
    }

    if (kIsWeb) {
      final userCreds = _getCredentialsForActiveUser();
      return userCreds
          .where((c) => c.categoryId == categoryId && !c.isDeleted)
          .toList();
    }

    try {
      final db = await _localDb.database;
      final key = await _getKey();

      final rows = await db.query(
        'credentials',
        where: 'user_id = ? AND category_id = ? AND is_deleted = ?',
        whereArgs: [_activeUserId, categoryId, 0],
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

      final userCreds = _getCredentialsForActiveUser();
      userCreds.removeWhere((c) => c.categoryId == categoryId);
      userCreds.addAll(list);

      return list;
    } catch (_) {
      final userCreds = _getCredentialsForActiveUser();
      return userCreds
          .where((c) => c.categoryId == categoryId && !c.isDeleted)
          .toList();
    }
  }

  @override
  Future<List<CredentialEntity>> getAllCredentials() async {
    final uid = _firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('credentials')
            .where('isDeleted', isEqualTo: false)
            .get();

        final list = snapshot.docs
            .map((d) => CredentialEntity.fromJson(d.data()))
            .toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        _userCredentials[_activeUserId] = list;
        return list;
      } catch (e) {
        debugPrint('Firestore getAllCredentials note: $e');
      }
    }

    if (kIsWeb) {
      final userCreds = _getCredentialsForActiveUser();
      return userCreds.where((c) => !c.isDeleted).toList();
    }

    try {
      final db = await _localDb.database;
      final key = await _getKey();

      final rows = await db.query(
        'credentials',
        where: 'user_id = ? AND is_deleted = ?',
        whereArgs: [_activeUserId, 0],
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

      _userCredentials[_activeUserId] = list;
      return list;
    } catch (_) {
      final userCreds = _getCredentialsForActiveUser();
      return userCreds.where((c) => !c.isDeleted).toList();
    }
  }

  @override
  Future<void> saveCredential(CredentialEntity credential) async {
    final userCreds = _getCredentialsForActiveUser();
    userCreds.removeWhere((c) => c.id == credential.id);
    userCreds.insert(0, credential);

    final uid = _firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('credentials')
            .doc(credential.id)
            .set(credential.toJson(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore saveCredential note: $e');
      }
    }

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
          'user_id': _activeUserId,
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
    final userCreds = _getCredentialsForActiveUser();
    final idx = userCreds.indexWhere((c) => c.id == id);
    if (idx != -1) {
      userCreds[idx] = userCreds[idx].copyWith(isDeleted: true);
    }

    final uid = _firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('credentials')
            .doc(id)
            .set({
          'isDeleted': true,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore deleteCredential note: $e');
      }
    }

    if (!kIsWeb) {
      try {
        final db = await _localDb.database;
        final now = DateTime.now().toUtc().toIso8601String();
        await db.update(
          'credentials',
          {'is_deleted': 1, 'updated_at': now},
          where: 'user_id = ? AND id = ?',
          whereArgs: [_activeUserId, id],
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
      _userCategories[_activeUserId]?.clear();
      _userCredentials[_activeUserId]?.clear();
    }
    for (final cat in categories) {
      await saveCategory(cat);
    }
    for (final cred in credentials) {
      await saveCredential(cred);
    }
  }
}
