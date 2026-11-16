import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_mail/core/crypto/backup_crypto_service.dart';
import 'package:my_mail/data/datasources/export_import_service.dart';
import 'package:my_mail/domain/entities/category_entity.dart';
import 'package:my_mail/domain/entities/credential_entity.dart';

void main() {
  late BackupCryptoService backupCryptoService;
  late ExportImportService exportImportService;

  setUp(() {
    backupCryptoService = BackupCryptoService();
    exportImportService = ExportImportService(
      backupCryptoService: backupCryptoService,
    );
  });

  group('BackupCryptoService & ExportImportService Unit Tests', () {
    const passphrase = 'SuperSecretBackupPassword2026!';
    final now = DateTime.now().toUtc();

    final testCategories = [
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
    ];

    final testCredentials = [
      CredentialEntity(
        id: 'cred_1',
        categoryId: 'cat_work',
        email: 'alice@company.com',
        password: 'CompanySecretPassword!1',
        label: 'Work Primary',
        createdAt: now,
        updatedAt: now,
      ),
      CredentialEntity(
        id: 'cred_2',
        categoryId: 'cat_personal',
        email: 'alice.private@gmail.com',
        password: 'PersonalPassword#99',
        label: 'Banking & Personal',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test('Encrypt backup creates valid JSON envelope with headers', () async {
      final payload = {
        'version': 1,
        'categories': testCategories.map((c) => c.toJson()).toList(),
        'credentials': testCredentials.map((c) => c.toJson()).toList(),
      };

      final encryptedJson = await backupCryptoService.encryptBackup(
        rawJson: jsonEncode(payload),
        passphrase: passphrase,
      );

      final decoded = jsonDecode(encryptedJson) as Map<String, dynamic>;
      expect(decoded['app'], equals('MyMail'));
      expect(decoded['version'], equals(1));
      expect(decoded['kdf'], equals('PBKDF2-HMAC-SHA256'));
      expect(decoded['iterations'], equals(100000));
      expect(decoded['salt'], isNotEmpty);
      expect(decoded['nonce'], isNotEmpty);
      expect(decoded['tag'], isNotEmpty);
      expect(decoded['ciphertext'], isNotEmpty);
    });

    test('Decrypt backup with correct passphrase restores exact data', () async {
      final payload = {
        'version': 1,
        'categories': testCategories.map((c) => c.toJson()).toList(),
        'credentials': testCredentials.map((c) => c.toJson()).toList(),
      };

      final encryptedJson = await backupCryptoService.encryptBackup(
        rawJson: jsonEncode(payload),
        passphrase: passphrase,
      );

      final backupData = await exportImportService.pickAndDecryptBackup(
        passphrase: passphrase,
        rawBackupJsonContent: encryptedJson,
      );

      expect(backupData, isNotNull);
      expect(backupData!.categories.length, equals(2));
      expect(backupData.credentials.length, equals(2));

      // Personal category must be preserved in encrypted backup
      expect(backupData.categories.any((c) => c.name == 'Personal'), isTrue);
      expect(backupData.credentials.any((c) => c.email == 'alice.private@gmail.com'), isTrue);
    });

    test('Decrypt backup with wrong passphrase throws InvalidPassphraseException', () async {
      final payload = {
        'version': 1,
        'categories': testCategories.map((c) => c.toJson()).toList(),
        'credentials': testCredentials.map((c) => c.toJson()).toList(),
      };

      final encryptedJson = await backupCryptoService.encryptBackup(
        rawJson: jsonEncode(payload),
        passphrase: passphrase,
      );

      expect(
        () async => await exportImportService.pickAndDecryptBackup(
          passphrase: 'WrongPassword123!',
          rawBackupJsonContent: encryptedJson,
        ),
        throwsA(isA<InvalidPassphraseException>()),
      );
    });

    test('Decrypt corrupt backup throws CorruptBackupException', () async {
      expect(
        () async => await backupCryptoService.decryptBackup(
          encryptedBackupJson: '{"invalid": "json format"}',
          passphrase: passphrase,
        ),
        throwsA(isA<CorruptBackupException>()),
      );
    });
  });
}
