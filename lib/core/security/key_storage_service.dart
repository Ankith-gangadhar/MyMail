import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../crypto/aes_gcm_service.dart';

class KeyStorageService {
  static const _vaultKeyName = 'mymail_master_vault_key';
  static const _autoLockTimeoutKey = 'mymail_auto_lock_timeout';
  static const _passphraseWrapKey = 'mymail_passphrase_wrap';
  static const _emailRecoveryEnabledKey = 'mymail_email_recovery_enabled';
  static const _screenCaptureProtectionKey = 'mymail_screen_capture_protection';

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

  /// Sets or updates the master vault encryption key explicitly.
  Future<void> saveMasterKey(String keyBase64) async {
    await _storage.write(key: _vaultKeyName, value: keyBase64);
  }

  /// Gets the existing master vault encryption key if stored.
  Future<String?> getMasterKey() async {
    return await _storage.read(key: _vaultKeyName);
  }

  /// Checks if a master vault key exists.
  Future<bool> hasMasterKey() async {
    final key = await _storage.read(key: _vaultKeyName);
    return key != null && key.isNotEmpty;
  }

  /// Saves local cached passphrase wrap
  Future<void> savePassphraseWrap(String jsonStr) async {
    await _storage.write(key: _passphraseWrapKey, value: jsonStr);
  }

  /// Gets cached passphrase wrap
  Future<String?> getPassphraseWrap() async {
    return await _storage.read(key: _passphraseWrapKey);
  }

  /// Sets email recovery preference (default: true)
  Future<void> setEmailRecoveryEnabled(bool enabled) async {
    await _storage.write(key: _emailRecoveryEnabledKey, value: enabled.toString());
  }

  /// Gets email recovery preference (default: true)
  Future<bool> getEmailRecoveryEnabled() async {
    final val = await _storage.read(key: _emailRecoveryEnabledKey);
    if (val == null) return true; // on by default
    return val == 'true';
  }

  /// Sets screen capture protection preference (default: true)
  Future<void> setScreenCaptureProtectionEnabled(bool enabled) async {
    await _storage.write(key: _screenCaptureProtectionKey, value: enabled.toString());
  }

  /// Gets screen capture protection preference (default: true)
  Future<bool> getScreenCaptureProtectionEnabled() async {
    final val = await _storage.read(key: _screenCaptureProtectionKey);
    if (val == null) return true; // on by default
    return val == 'true';
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
