import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../crypto/aes_gcm_service.dart';

class KeyStorageService {
  static const _vaultKeyName = 'mymail_master_vault_key';
  static const _autoLockTimeoutKey = 'mymail_auto_lock_timeout';

  final FlutterSecureStorage _storage;
  final AesGcmService _aesGcmService;

  KeyStorageService({
    FlutterSecureStorage? storage,
    AesGcmService? aesGcmService,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
            ),
        _aesGcmService = aesGcmService ?? AesGcmService();

  /// Gets the existing master vault encryption key or generates and stores a new one.
  Future<String> getOrCreateMasterKey() async {
    String? key = await _storage.read(key: _vaultKeyName);
    if (key == null || key.isEmpty) {
      key = await _aesGcmService.generateKeyBase64();
      await _storage.write(key: _vaultKeyName, value: key);
    }
    return key;
  }

  /// Sets auto lock timeout ('immediate', '1min', '5min')
  Future<void> setAutoLockTimeout(String timeout) async {
    await _storage.write(key: _autoLockTimeoutKey, value: timeout);
  }

  /// Gets auto lock timeout, default is '1min'
  Future<String> getAutoLockTimeout() async {
    final timeout = await _storage.read(key: _autoLockTimeoutKey);
    return timeout ?? '1min';
  }

  /// Wipes all secure keys
  Future<void> wipeAll() async {
    await _storage.deleteAll();
  }
}
