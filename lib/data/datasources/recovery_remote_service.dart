import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/crypto/vault_key_wrapping_service.dart';

class RecoveryRemoteService {
  final FirebaseAuth? _injectedAuth;
  final FirebaseFirestore? _injectedFirestore;
  final FirebaseFunctions? _injectedFunctions;
  final GoogleSignIn? _injectedGoogleSignIn;
  static bool _googleSignInInitialized = false;

  RecoveryRemoteService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    GoogleSignIn? googleSignIn,
  })  : _injectedAuth = auth,
        _injectedFirestore = firestore,
        _injectedFunctions = functions,
        _injectedGoogleSignIn = googleSignIn;

  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _injectedFirestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions => _injectedFunctions ?? FirebaseFunctions.instance;
  GoogleSignIn get _googleSignIn => _injectedGoogleSignIn ?? GoogleSignIn.instance;

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// On Web, checks if a redirect sign-in just completed
  Future<UserCredential?> getRedirectResult() async {
    try {
      if (kIsWeb) {
        return await _auth.getRedirectResult();
      }
    } catch (_) {}
    return null;
  }

  /// Signs in using Google Sign-In and Firebase Auth.
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        try {
          return await _auth.signInWithPopup(googleProvider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-blocked' || e.code == 'cancelled-popup-request') {
            await _auth.signInWithRedirect(googleProvider);
            return await _auth.getRedirectResult();
          }
          rethrow;
        }
      }

      // Android / iOS native Google Sign-In
      if (!_googleSignInInitialized) {
        try {
          await _googleSignIn.initialize();
          _googleSignInInitialized = true;
        } catch (e) {
          _googleSignInInitialized = true;
        }
      }

      final account = await _googleSignIn.authenticate();
      final auth = account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign-In caught error: $e');
      rethrow;
    }
  }

  /// Signs in with standard Email and Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates a new account with Email and Password
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (credential.user != null && displayName.isNotEmpty) {
      await credential.user!.updateDisplayName(displayName.trim());
    }
    return credential;
  }

  /// Sends password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Signs out from all auth providers
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
  }

  /// Ensures user is signed in with Google, or triggers the sign-in flow.
  Future<User> ensureAuthenticated() async {
    final user = _auth.currentUser;
    if (user != null) return user;
    final creds = await signInWithGoogle();
    if (creds.user == null) {
      throw Exception('Authentication failed');
    }
    return creds.user!;
  }

  /// Saves the user's Argon2id passphrase wrap to Firestore under users/{uid}
  Future<void> savePassphraseWrap({
    required String uid,
    required PassphraseWrap wrap,
    bool? emailRecoveryEnabled,
  }) async {
    final data = <String, dynamic>{
      'passphrase_wrap': wrap.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (emailRecoveryEnabled != null) {
      data['emailRecoveryEnabled'] = emailRecoveryEnabled;
    }

    await _firestore.collection('users').doc(uid).set(
          data,
          SetOptions(merge: true),
        );
  }

  /// Gets the passphrase wrap from Firestore for the given user.
  Future<PassphraseWrap?> getPassphraseWrap(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || !data.containsKey('passphrase_wrap')) return null;

    final wrapMap = Map<String, dynamic>.from(data['passphrase_wrap'] as Map);
    return PassphraseWrap.fromMap(wrapMap);
  }

  /// Sets recovery wrap via Cloud KMS in Cloud Functions.
  /// Passes the Vault Key over TLS so KMS can encrypt it into the recovery wrap.
  Future<void> setRecoveryWrap({
    required String vaultKeyBase64,
  }) async {
    await ensureAuthenticated();
    final callable = _functions.httpsCallable('setRecoveryWrap');
    await callable.call<Map<String, dynamic>>({
      'vaultKey': vaultKeyBase64,
    });
  }

  /// Requests email-based passphrase recovery.
  /// Cloud Function verifies auth ID token, generates a 6-digit code (valid for 15 mins),
  /// stores only its SHA-256 hash in users/{uid}/private/recovery, and sends the code to
  /// the registered Google email address.
  Future<Map<String, dynamic>> requestRecovery() async {
    await ensureAuthenticated();
    final callable = _functions.httpsCallable('requestRecovery');
    final result = await callable.call<Map<String, dynamic>>();
    return Map<String, dynamic>.from(result.data);
  }

  /// Verifies the 6-digit recovery code.
  /// If valid and not expired, Cloud Function decrypts the Vault Key using Cloud KMS
  /// and returns it over TLS to this session.
  /// Throws error on wrong code, expired code, reused code, or > 5 attempts.
  Future<String> verifyRecovery({
    required String code,
  }) async {
    await ensureAuthenticated();
    final callable = _functions.httpsCallable('verifyRecovery');
    final result = await callable.call<Map<String, dynamic>>({
      'code': code.trim(),
    });

    final data = Map<String, dynamic>.from(result.data);
    final vaultKey = data['vaultKey'] as String?;
    if (vaultKey == null || vaultKey.isEmpty) {
      throw Exception('Verification succeeded but Vault Key was missing.');
    }
    return vaultKey;
  }

  /// Toggles email recovery on/off.
  Future<void> setEmailRecoveryEnabled({
    required String uid,
    required bool enabled,
    String? vaultKeyBase64,
  }) async {
    await ensureAuthenticated();
    if (enabled && vaultKeyBase64 != null) {
      await setRecoveryWrap(vaultKeyBase64: vaultKeyBase64);
    } else if (!enabled) {
      final callable = _functions.httpsCallable('disableRecovery');
      await callable.call();
    }

    await _firestore.collection('users').doc(uid).set({
      'emailRecoveryEnabled': enabled,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Checks if email recovery is enabled in user's profile document.
  Future<bool> isEmailRecoveryEnabled(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return true; // Default true
    final data = doc.data();
    return (data?['emailRecoveryEnabled'] as bool?) ?? true;
  }
}
