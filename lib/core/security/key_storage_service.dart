import 'package:flutter/foundation.dart';
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
  final Map<String, String> _memoryFallback = {};

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

  Future<void> _write(String key, String value) async {
    _memoryFallback[key] = value;
    if (!kIsWeb) {
      try {
        await _storage.write(key: key, value: value);
      } catch (_) {}
    }
  }

  Future<String?> _read(String key) async {
    if (_memoryFallback.containsKey(key)) {
      return _memoryFallback[key];
    }
    if (!kIsWeb) {
      try {
        final val = await _storage.read(key: key);
        if (val != null) {
          _memoryFallback[key] = val;
          return val;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Gets the existing master vault encryption key or generates and stores a new one.
  Future<String> getOrCreateMasterKey() async {
    String? key = await _read(_vaultKeyName);
    if (key == null || key.isEmpty) {
      key = await _aesGcmService.generateKeyBase64();
      await _write(_vaultKeyName, key);
    }
    return key;
  }

  /// Sets or updates the master vault encryption key explicitly.
  Future<void> saveMasterKey(String keyBase64) async {
    await _write(_vaultKeyName, keyBase64);
  }

  /// Gets the existing master vault encryption key if stored.
  Future<String?> getMasterKey() async {
    return await _read(_vaultKeyName);
  }

  /// Checks if a master vault key exists.
  Future<bool> hasMasterKey() async {
    final key = await _read(_vaultKeyName);
    return key != null && key.isNotEmpty;
  }

  /// Saves local cached passphrase wrap
  Future<void> savePassphraseWrap(String jsonStr) async {
    await _write(_passphraseWrapKey, jsonStr);
  }

  /// Gets cached passphrase wrap
  Future<String?> getPassphraseWrap() async {
    return await _read(_passphraseWrapKey);
  }

  /// Sets email recovery preference (default: true)
  Future<void> setEmailRecoveryEnabled(bool enabled) async {
    await _write(_emailRecoveryEnabledKey, enabled.toString());
  }

  /// Gets email recovery preference (default: true)
  Future<bool> getEmailRecoveryEnabled() async {
    final val = await _read(_emailRecoveryEnabledKey);
    if (val == null) return true; // on by default
    return val == 'true';
  }

  /// Sets screen capture protection preference (default: false)
  Future<void> setScreenCaptureProtectionEnabled(bool enabled) async {
    await _write(_screenCaptureProtectionKey, enabled.toString());
  }

  /// Gets screen capture protection preference (default: false)
  Future<bool> getScreenCaptureProtectionEnabled() async {
    final val = await _read(_screenCaptureProtectionKey);
    if (val == null) return false;
    return val == 'true';
  }

  /// Sets auto lock timeout ('immediate', '1min', '5min')
  Future<void> setAutoLockTimeout(String timeout) async {
    await _write(_autoLockTimeoutKey, timeout);
  }

  /// Gets auto lock timeout, default is '5min'
  Future<String> getAutoLockTimeout() async {
    final timeout = await _read(_autoLockTimeoutKey);
    return timeout ?? '5min';
  }

  /// Wipes all secure keys
  Future<void> wipeAll() async {
    _memoryFallback.clear();
    if (!kIsWeb) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }
}
