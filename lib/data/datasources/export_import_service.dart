import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/crypto/backup_crypto_service.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/credential_entity.dart';

class BackupData {
  final List<CategoryEntity> categories;
  final List<CredentialEntity> credentials;

  BackupData({
    required this.categories,
    required this.credentials,
  });
}

class ExportImportService {
  final BackupCryptoService _backupCryptoService;

  ExportImportService({BackupCryptoService? backupCryptoService})
      : _backupCryptoService = backupCryptoService ?? BackupCryptoService();

  /// Exports category credentials as an Excel (.xlsx) file and opens the Android share sheet.
  /// Strictly rejects the "Personal" category to prevent accidental plaintext leakage.
  Future<void> shareCategoryAsExcel({
    required CategoryEntity category,
    required List<CredentialEntity> credentials,
  }) async {
    if (category.name.trim().toLowerCase() == 'personal' ||
        category.id == 'cat_personal') {
      throw ArgumentError('The Personal category cannot be exported to an unencrypted Excel file.');
    }

    final excel = Excel.createExcel();
    final Sheet sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    // Header row
    sheet.appendRow([
      TextCellValue('Email'),
      TextCellValue('Password'),
      TextCellValue('Label'),
    ]);

    // Data rows
    for (final cred in credentials) {
      if (cred.isDeleted) continue;
      sheet.appendRow([
        TextCellValue(cred.email),
        TextCellValue(cred.password),
        TextCellValue(cred.label ?? ''),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel document.');
    }

    final tempDir = await getTemporaryDirectory();
    final sanitizedCategoryName = category.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'MyMail_${sanitizedCategoryName}_$dateStr.xlsx';
    final tempFile = File('${tempDir.path}/$fileName');

    await tempFile.writeAsBytes(fileBytes);

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          subject: 'MyMail Export - ${category.name}',
        ),
      );
    } finally {
      // Clean up temporary unencrypted file after sharing
      Future.delayed(const Duration(seconds: 15), () async {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      });
    }
  }

  /// Exports all categories and credentials encrypted with the user's passphrase.
  Future<void> exportEncryptedBackup({
    required List<CategoryEntity> categories,
    required List<CredentialEntity> credentials,
    required String passphrase,
  }) async {
    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'credentials': credentials.map((c) => c.toJson()).toList(),
    };

    final rawJson = jsonEncode(payload);
    final encryptedEnvelopeJson = await _backupCryptoService.encryptBackup(
      rawJson: rawJson,
      passphrase: passphrase,
    );

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'MyMail_Backup_$dateStr.mymail';
    final tempFile = File('${tempDir.path}/$fileName');

    await tempFile.writeAsString(encryptedEnvelopeJson);

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          subject: 'MyMail Encrypted Vault Backup ($dateStr)',
        ),
      );
    } finally {
      Future.delayed(const Duration(seconds: 20), () async {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      });
    }
  }

  /// Picks a backup file and decrypts it with the provided passphrase.
  Future<BackupData?> pickAndDecryptBackup({
    required String passphrase,
    String? rawBackupJsonContent,
  }) async {
    String fileContent;

    if (rawBackupJsonContent != null) {
      fileContent = rawBackupJsonContent;
    } else {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (files.isEmpty || files.first.path == null) {
        return null; // User cancelled
      }

      final file = File(files.first.path!);
      fileContent = await file.readAsString();
    }

    final decryptedJsonStr = await _backupCryptoService.decryptBackup(
      encryptedBackupJson: fileContent,
      passphrase: passphrase,
    );

    final Map<String, dynamic> data = jsonDecode(decryptedJsonStr) as Map<String, dynamic>;

    final rawCategories = data['categories'] as List<dynamic>? ?? [];
    final rawCredentials = data['credentials'] as List<dynamic>? ?? [];

    final categories = rawCategories
        .map((c) => CategoryEntity.fromJson(c as Map<String, dynamic>))
        .toList();

    final credentials = rawCredentials
        .map((c) => CredentialEntity.fromJson(c as Map<String, dynamic>))
        .toList();

    return BackupData(
      categories: categories,
      credentials: credentials,
    );
  }
}
