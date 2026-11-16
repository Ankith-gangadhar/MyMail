import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class EncryptedData {
  final String ciphertextBase64;
  final String nonceBase64;
  final String macBase64;

  const EncryptedData({
    required this.ciphertextBase64,
    required this.nonceBase64,
    required this.macBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'c': ciphertextBase64,
      'n': nonceBase64,
      'm': macBase64,
    };
  }

  factory EncryptedData.fromMap(Map<String, dynamic> map) {
    return EncryptedData(
      ciphertextBase64: map['c'] as String,
      nonceBase64: map['n'] as String,
      macBase64: map['m'] as String,
    );
  }

  String serialize() => jsonEncode(toMap());

  factory EncryptedData.deserialize(String jsonStr) {
    return EncryptedData.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}

class AesGcmService {
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Generates a new 256-bit AES key and returns it as a Base64 string.
  Future<String> generateKeyBase64() async {
    final secretKey = await _algorithm.newSecretKey();
    final bytes = await secretKey.extractBytes();
    return base64Encode(bytes);
  }

  /// Encrypts plain text string with AES-256-GCM.
  Future<EncryptedData> encrypt({
    required String plainText,
    required String keyBase64,
  }) async {
    final keyBytes = base64Decode(keyBase64);
    final secretKey = SecretKey(keyBytes);
    final clearTextBytes = utf8.encode(plainText);

    final secretBox = await _algorithm.encrypt(
      clearTextBytes,
      secretKey: secretKey,
    );

    return EncryptedData(
      ciphertextBase64: base64Encode(secretBox.cipherText),
      nonceBase64: base64Encode(secretBox.nonce),
      macBase64: base64Encode(secretBox.mac.bytes),
    );
  }

  /// Decrypts AES-256-GCM payload to plain text.
  Future<String> decrypt({
    required EncryptedData encryptedData,
    required String keyBase64,
  }) async {
    final keyBytes = base64Decode(keyBase64);
    final secretKey = SecretKey(keyBytes);

    final cipherText = base64Decode(encryptedData.ciphertextBase64);
    final nonce = base64Decode(encryptedData.nonceBase64);
    final macBytes = base64Decode(encryptedData.macBase64);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearTextBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(clearTextBytes);
  }
}
