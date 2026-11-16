import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_mail/core/crypto/aes_gcm_service.dart';
import 'package:my_mail/core/crypto/vault_key_wrapping_service.dart';

void main() {
  late VaultKeyWrappingService wrappingService;
  late AesGcmService aesGcmService;
  late String masterVaultKeyBase64;

  setUp(() async {
    wrappingService = VaultKeyWrappingService();
    aesGcmService = AesGcmService();
    masterVaultKeyBase64 = await aesGcmService.generateKeyBase64();
  });

  group('Argon2id + AES-256-GCM Vault Key Wrapping Tests', () {
    test('Wrap and unwrap roundtrip preserves exact 256-bit Vault Key', () async {
      const passphrase = 'MySuperSecurePassphrase!2026';

      final wrap = await wrappingService.wrapVaultKey(
        vaultKeyBase64: masterVaultKeyBase64,
        passphrase: passphrase,
      );

      expect(wrap.ciphertextBase64, isNotEmpty);
      expect(wrap.nonceBase64, isNotEmpty);
      expect(wrap.macBase64, isNotEmpty);
      expect(wrap.saltBase64, isNotEmpty);
      expect(wrap.algorithm, equals('Argon2id+AES-256-GCM'));

      // Unwrap with correct passphrase
      final unwrappedKey = await wrappingService.unwrapVaultKey(
        wrap: wrap,
        passphrase: passphrase,
      );

      expect(unwrappedKey, equals(masterVaultKeyBase64));
    });

    test('Unwrap with wrong passphrase throws an authentication exception', () async {
      const passphrase = 'CorrectPassphrase!123';
      const wrongPassphrase = 'WrongPassphrase!456';

      final wrap = await wrappingService.wrapVaultKey(
        vaultKeyBase64: masterVaultKeyBase64,
        passphrase: passphrase,
      );

      expect(
        () async => await wrappingService.unwrapVaultKey(
          wrap: wrap,
          passphrase: wrongPassphrase,
        ),
        throwsA(anything),
      );
    });

    test('Passphrase change re-wraps the Vault Key without re-encrypting vault data', () async {
      const originalPassphrase = 'Passphrase_Phase1';
      const newPassphrase = 'Passphrase_Phase2';

      // 1. Data encrypted with original Vault Key
      const confidentialAccountData = '{"email":"vip@gmail.com","password":"secret_password"}';
      final encryptedData = await aesGcmService.encrypt(
        plainText: confidentialAccountData,
        keyBase64: masterVaultKeyBase64,
      );

      // 2. Wrap VK with original passphrase
      final wrap1 = await wrappingService.wrapVaultKey(
        vaultKeyBase64: masterVaultKeyBase64,
        passphrase: originalPassphrase,
      );
      expect(await wrappingService.unwrapVaultKey(wrap: wrap1, passphrase: originalPassphrase), equals(masterVaultKeyBase64));

      // 3. User changes passphrase: ONLY re-wraps the VK
      final wrap2 = await wrappingService.wrapVaultKey(
        vaultKeyBase64: masterVaultKeyBase64,
        passphrase: newPassphrase,
      );

      // 4. Unwrap with new passphrase
      final recoveredVaultKey = await wrappingService.unwrapVaultKey(
        wrap: wrap2,
        passphrase: newPassphrase,
      );
      expect(recoveredVaultKey, equals(masterVaultKeyBase64));

      // 5. Existing encrypted data is decrypted with unchanged Vault Key! No re-encryption required!
      final decryptedData = await aesGcmService.decrypt(
        encryptedData: encryptedData,
        keyBase64: recoveredVaultKey,
      );
      expect(decryptedData, equals(confidentialAccountData));
    });

    test('Confirm plaintext passphrase is NEVER stored in wrap payload or sent to server', () async {
      const secretPassphrase = 'my_top_secret_passphrase_never_leak';

      final wrap = await wrappingService.wrapVaultKey(
        vaultKeyBase64: masterVaultKeyBase64,
        passphrase: secretPassphrase,
      );

      final serialized = wrap.toJson();

      // Ensure secretPassphrase substring is nowhere in the serialized JSON
      expect(serialized.contains(secretPassphrase), isFalse);

      final map = wrap.toMap();
      expect(map.values.any((val) => val.toString().contains(secretPassphrase)), isFalse);
    });
  });

  group('Email Recovery State Machine Unit Tests', () {
    // Simulated mock Firestore recovery record structure
    late Map<String, dynamic> mockRecoveryRecord;
    const testCode = '482910';

    Future<String> computeHash(String code) async {
      final digest = await Sha256().hash(utf8.encode(code));
      return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }

    setUp(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      mockRecoveryRecord = {
        'codeHash': await computeHash(testCode),
        'expiresAt': now + (15 * 60 * 1000), // 15 minutes
        'attempts': 0,
        'isUsed': false,
        'recoveryWrap': base64Encode(utf8.encode('mock_kms_encrypted_vault_key')),
      };
    });

    Future<String?> simulateVerifyRecovery(String enteredCode, {int? simulatedCurrentTime}) async {
      final now = simulatedCurrentTime ?? DateTime.now().millisecondsSinceEpoch;

      if (mockRecoveryRecord['isUsed'] == true) {
        throw Exception('Recovery code has already been used.');
      }
      if (now > (mockRecoveryRecord['expiresAt'] as int)) {
        throw Exception('Recovery code has expired (15 minute limit).');
      }
      if ((mockRecoveryRecord['attempts'] as int) >= 5) {
        throw Exception('Maximum verification attempts (5) reached. Please request a new code.');
      }

      final inputHash = await computeHash(enteredCode.trim());
      if (inputHash != mockRecoveryRecord['codeHash']) {
        mockRecoveryRecord['attempts'] = (mockRecoveryRecord['attempts'] as int) + 1;
        final remaining = 5 - (mockRecoveryRecord['attempts'] as int);
        throw Exception('Invalid recovery code. $remaining attempt(s) remaining.');
      }

      // Mark used
      mockRecoveryRecord['isUsed'] = true;
      return mockRecoveryRecord['recoveryWrap'] as String;
    }

    test('Verification with correct 6-digit code succeeds and marks code as single-use', () async {
      final result = await simulateVerifyRecovery(testCode);
      expect(result, isNotNull);
      expect(mockRecoveryRecord['isUsed'], isTrue);
    });

    test('Verification with wrong code increments attempt count and throws invalid code', () async {
      expect(
        () async => await simulateVerifyRecovery('111111'),
        throwsA(predicate((e) => e.toString().contains('Invalid recovery code. 4 attempt(s) remaining'))),
      );
    });

    test('Verification with expired code (>15 minutes) is rejected', () async {
      final futureTime = DateTime.now().millisecondsSinceEpoch + (16 * 60 * 1000); // 16 mins later
      expect(
        () async => await simulateVerifyRecovery(testCode, simulatedCurrentTime: futureTime),
        throwsA(predicate((e) => e.toString().contains('Recovery code has expired'))),
      );
    });

    test('Reusing a previously verified code is strictly rejected (single-use enforcement)', () async {
      // First attempt succeeds
      final res1 = await simulateVerifyRecovery(testCode);
      expect(res1, isNotNull);

      // Reused attempt
      expect(
        () async => await simulateVerifyRecovery(testCode),
        throwsA(predicate((e) => e.toString().contains('Recovery code has already been used'))),
      );
    });

    test('Exceeding 5 failed attempts locks the code until new code is requested', () async {
      for (int i = 0; i < 5; i++) {
        try {
          await simulateVerifyRecovery('99999$i');
        } catch (_) {}
      }

      expect(mockRecoveryRecord['attempts'], equals(5));

      // 6th attempt with even correct code is rejected because max attempts reached
      expect(
        () async => await simulateVerifyRecovery(testCode),
        throwsA(predicate((e) => e.toString().contains('Maximum verification attempts (5) reached'))),
      );
    });
  });
}

