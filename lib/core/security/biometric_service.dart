import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// Checks if the device has security hardware / enrolled lock (biometrics or device PIN/pattern/password).
  Future<bool> isDeviceSecured() async {
    if (kIsWeb) return true;
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) {
        return false;
      }
      final canCheck = await _auth.canCheckBiometrics;
      final biometrics = await _auth.getAvailableBiometrics();
      return isSupported && (canCheck || biometrics.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user to authenticate with biometrics or fallback to device PIN/password/pattern.
  Future<bool> authenticate({
    required String localizedReason,
    bool sensitiveTransaction = true,
  }) async {
    if (kIsWeb) return true;
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false, // Allows PIN/pattern/password fallback
        sensitiveTransaction: sensitiveTransaction,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
