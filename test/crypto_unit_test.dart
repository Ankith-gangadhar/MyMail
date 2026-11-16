import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_mail/core/crypto/aes_gcm_service.dart';

void main() {
  late AesGcmService aesGcmService;
  late String masterKeyBase64;

  setUp(() async {
    aesGcmService = AesGcmService();
    masterKeyBase64 = await aesGcmService.generateKeyBase64();
  });

  group('AesGcmService Unit Tests', () {
    test('generateKeyBase64 generates valid 256-bit key', () {
      final keyBytes = base64Decode(masterKeyBase64);
      expect(keyBytes.length, equals(32)); // 256 bits = 32 bytes
    });

    test('Encrypt and decrypt roundtrip preserves exact plaintext', () async {
      const plainText = 'my_super_secure_password_#123@!';
      final encrypted = await aesGcmService.encrypt(
        plainText: plainText,
        keyBase64: masterKeyBase64,
      );

      expect(encrypted.ciphertextBase64, isNotEmpty);
      expect(encrypted.nonceBase64, isNotEmpty);
      expect(encrypted.macBase64, isNotEmpty);

      // Decrypt
      final decrypted = await aesGcmService.decrypt(
        encryptedData: encrypted,
        keyBase64: masterKeyBase64,
      );

      expect(decrypted, equals(plainText));
    });

    test('Each encryption generates a unique nonce', () async {
      const plainText = 'same_password_twice';
      final enc1 = await aesGcmService.encrypt(
        plainText: plainText,
        keyBase64: masterKeyBase64,
      );
      final enc2 = await aesGcmService.encrypt(
        plainText: plainText,
        keyBase64: masterKeyBase64,
      );

      expect(enc1.nonceBase64, isNot(equals(enc2.nonceBase64)));
      expect(enc1.ciphertextBase64, isNot(equals(enc2.ciphertextBase64)));
    });

    test('Tampered ciphertext throws an authentication exception', () async {
      const plainText = 'secret_content';
      final encrypted = await aesGcmService.encrypt(
        plainText: plainText,
        keyBase64: masterKeyBase64,
      );

      // Tamper ciphertext
      final tamperedBytes = base64Decode(encrypted.ciphertextBase64);
      tamperedBytes[0] = tamperedBytes[0] ^ 0xFF;
      final tampered = EncryptedData(
        ciphertextBase64: base64Encode(tamperedBytes),
        nonceBase64: encrypted.nonceBase64,
        macBase64: encrypted.macBase64,
      );

      expect(
        () async => await aesGcmService.decrypt(
          encryptedData: tampered,
          keyBase64: masterKeyBase64,
        ),
        throwsA(anything),
      );
    });
  });
}
