import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class BackupCryptoException implements Exception {
  final String message;
  BackupCryptoException(this.message);
  @override
  String toString() => message;
}

class InvalidPassphraseException extends BackupCryptoException {
  InvalidPassphraseException() : super('Incorrect passphrase or corrupted backup.');
}

class CorruptBackupException extends BackupCryptoException {
  CorruptBackupException(super.message);
}

class BackupCryptoService {
  static const int _saltLength = 16;
  static const int _iterations = 100000;
  final AesGcm _aesGcm = AesGcm.with256bits();

  /// Encrypts raw JSON string using a user passphrase with PBKDF2 + AES-256-GCM.
  Future<String> encryptBackup({
    required String rawJson,
    required String passphrase,
  }) async {
    // Generate 16 bytes cryptographically secure random salt
    final secureRandom = Random.secure();
    final salt = Uint8List(_saltLength);
    for (int i = 0; i < _saltLength; i++) {
      salt[i] = secureRandom.nextInt(256);
    }

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );

    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final clearTextBytes = utf8.encode(rawJson);
    final secretBox = await _aesGcm.encrypt(
      clearTextBytes,
      secretKey: secretKey,
    );

    final envelope = {
      'app': 'MyMail',
      'version': 1,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'tag': base64Encode(secretBox.mac.bytes),
      'ciphertext': base64Encode(secretBox.cipherText),
    };

    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Decrypts encrypted backup JSON file using the user passphrase.
  Future<String> decryptBackup({
    required String encryptedBackupJson,
    required String passphrase,
  }) async {
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(encryptedBackupJson) as Map<String, dynamic>;
    } catch (e) {
      throw CorruptBackupException('The selected file is not a valid JSON backup file.');
    }

    if (envelope['app'] != 'MyMail' || envelope['version'] != 1) {
      throw CorruptBackupException('Unrecognized or incompatible backup format.');
    }

    final saltBase64 = envelope['salt'] as String?;
    final nonceBase64 = envelope['nonce'] as String?;
    final tagBase64 = envelope['tag'] as String?;
    final ciphertextBase64 = envelope['ciphertext'] as String?;
    final iterations = envelope['iterations'] as int? ?? _iterations;

    if (saltBase64 == null ||
        nonceBase64 == null ||
        tagBase64 == null ||
        ciphertextBase64 == null) {
      throw CorruptBackupException('Backup file is missing required cryptographic headers.');
    }

    try {
      final salt = base64Decode(saltBase64);
      final nonce = base64Decode(nonceBase64);
      final tag = base64Decode(tagBase64);
      final ciphertext = base64Decode(ciphertextBase64);

      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );

      final secretKey = await pbkdf2.deriveKeyFromPassword(
        password: passphrase,
        nonce: salt,
      );

      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(tag),
      );

      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(decryptedBytes);
    } on SecretBoxAuthenticationError {
      throw InvalidPassphraseException();
    } catch (e) {
      if (e is BackupCryptoException) rethrow;
      throw InvalidPassphraseException();
    }
  }
}
