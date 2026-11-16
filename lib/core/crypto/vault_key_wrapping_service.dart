import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Container for the passphrase-wrapped Vault Key (VK).
class PassphraseWrap {
  final String ciphertextBase64;
  final String nonceBase64;
  final String macBase64;
  final String saltBase64;
  final String algorithm;
  final int memory;
  final int iterations;
  final int parallelism;

  const PassphraseWrap({
    required this.ciphertextBase64,
    required this.nonceBase64,
    required this.macBase64,
    required this.saltBase64,
    this.algorithm = 'Argon2id+AES-256-GCM',
    this.memory = 19456, // 19 MiB
    this.iterations = 2,
    this.parallelism = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'ciphertext': ciphertextBase64,
      'nonce': nonceBase64,
      'mac': macBase64,
      'salt': saltBase64,
      'algorithm': algorithm,
      'memory': memory,
      'iterations': iterations,
      'parallelism': parallelism,
    };
  }

  factory PassphraseWrap.fromMap(Map<String, dynamic> map) {
    return PassphraseWrap(
      ciphertextBase64: map['ciphertext'] as String,
      nonceBase64: map['nonce'] as String,
      macBase64: map['mac'] as String,
      saltBase64: map['salt'] as String,
      algorithm: (map['algorithm'] as String?) ?? 'Argon2id+AES-256-GCM',
      memory: (map['memory'] as num?)?.toInt() ?? 19456,
      iterations: (map['iterations'] as num?)?.toInt() ?? 2,
      parallelism: (map['parallelism'] as num?)?.toInt() ?? 1,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PassphraseWrap.fromJson(String jsonStr) {
    return PassphraseWrap.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}

/// Service that wraps and unwraps the 256-bit Vault Key (VK)
/// using Argon2id for password-based key derivation (KEK) and AES-256-GCM.
class VaultKeyWrappingService {
  final AesGcm _aesGcm = AesGcm.with256bits();

  /// Wraps a 256-bit Vault Key [vaultKeyBase64] using a [passphrase].
  /// Derives a Key Encryption Key (KEK) via Argon2id with a fresh 16-byte random salt.
  Future<PassphraseWrap> wrapVaultKey({
    required String vaultKeyBase64,
    required String passphrase,
    List<int>? explicitSalt,
  }) async {
    // Generate 16 bytes of random salt if not provided
    final salt = explicitSalt ?? _generateRandomBytes(16);

    const memory = 19456;
    const iterations = 2;
    const parallelism = 1;

    final argon2id = Argon2id(
      parallelism: parallelism,
      memory: memory,
      iterations: iterations,
      hashLength: 32,
    );

    final kek = await argon2id.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );

    final vkBytes = base64Decode(vaultKeyBase64);
    final secretBox = await _aesGcm.encrypt(
      vkBytes,
      secretKey: kek,
    );

    return PassphraseWrap(
      ciphertextBase64: base64Encode(secretBox.cipherText),
      nonceBase64: base64Encode(secretBox.nonce),
      macBase64: base64Encode(secretBox.mac.bytes),
      saltBase64: base64Encode(salt),
      algorithm: 'Argon2id+AES-256-GCM',
      memory: memory,
      iterations: iterations,
      parallelism: parallelism,
    );
  }

  /// Unwraps the Vault Key (VK) from [wrap] using the user's [passphrase].
  /// Returns the base64-encoded 256-bit Vault Key.
  /// Throws an exception if the passphrase is incorrect or data was tampered with.
  Future<String> unwrapVaultKey({
    required PassphraseWrap wrap,
    required String passphrase,
  }) async {
    final salt = base64Decode(wrap.saltBase64);

    final argon2id = Argon2id(
      parallelism: wrap.parallelism,
      memory: wrap.memory,
      iterations: wrap.iterations,
      hashLength: 32,
    );

    final kek = await argon2id.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );

    final secretBox = SecretBox(
      base64Decode(wrap.ciphertextBase64),
      nonce: base64Decode(wrap.nonceBase64),
      mac: Mac(base64Decode(wrap.macBase64)),
    );

    final vkBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: kek,
    );

    return base64Encode(vkBytes);
  }

  List<int> _generateRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
