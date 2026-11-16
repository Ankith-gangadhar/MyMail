import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vault_providers.dart';
import '../widgets/glass_container.dart';
import 'home_screen.dart';

class AuthGuardScreen extends ConsumerStatefulWidget {
  const AuthGuardScreen({super.key});

  @override
  ConsumerState<AuthGuardScreen> createState() => _AuthGuardScreenState();
}

class _AuthGuardScreenState extends ConsumerState<AuthGuardScreen>
    with WidgetsBindingObserver {
  Timer? _inactivityCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Periodic check for inactivity timeout
    _inactivityCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.read(authNotifierProvider.notifier).checkInactivityTimeout();
    });
  }

  @override
  void dispose() {
    _inactivityCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(authNotifierProvider.notifier).handleAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        ref.read(authNotifierProvider.notifier).recordActivity();
      },
      child: switch (authState.status) {
        AuthStatus.deviceSecurityMissing => const _DeviceSecurityMissingView(),
        AuthStatus.locked => const _VaultLockedView(),
        AuthStatus.authenticated => const HomeScreen(),
        _ => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      },
    );
  }
}

class _DeviceSecurityMissingView extends ConsumerWidget {
  const _DeviceSecurityMissingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.gpp_bad_rounded,
                  size: 52,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Device Screen Lock Required',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'MyMail is an offline-first encrypted vault. To protect your stored credentials, your phone must have a secure screen lock (PIN, pattern, password, or biometrics) enabled in your Android system settings.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Check Again'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ref.read(authNotifierProvider.notifier).initialize();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultLockedView extends ConsumerStatefulWidget {
  const _VaultLockedView();

  @override
  ConsumerState<_VaultLockedView> createState() => _VaultLockedViewState();
}

class _VaultLockedViewState extends ConsumerState<_VaultLockedView> {
  bool _isRequestingRecovery = false;

  Future<void> _startForgotPassphraseFlow() async {
    setState(() => _isRequestingRecovery = true);

    try {
      final maskedEmail = await ref.read(authNotifierProvider.notifier).requestRecovery();
      if (!mounted) return;
      setState(() => _isRequestingRecovery = false);

      await _showRecoveryCodeDialog(maskedEmail);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRequestingRecovery = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recovery request failed: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _showRecoveryCodeDialog(String maskedEmail) async {
    final codeController = TextEditingController();
    String? errorMessage;
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.mark_email_read_outlined, color: Colors.blue),
              SizedBox(width: 10),
              Text('Enter Recovery Code'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We sent a 6-digit recovery code to $maskedEmail.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Expires in 15 minutes\n• Single-use only\n• Maximum 5 verification attempts',
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '123456',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    color: Colors.grey.shade300,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: errorMessage,
                ),
              ),
              if (isVerifying)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.length != 6) {
                        setLocalState(() {
                          errorMessage = 'Please enter all 6 digits';
                        });
                        return;
                      }

                      setLocalState(() {
                        isVerifying = true;
                        errorMessage = null;
                      });

                      try {
                        final vaultKey = await ref
                            .read(authNotifierProvider.notifier)
                            .verifyRecoveryCode(code);

                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop(); // Close code dialog

                        // Proceed immediately to set new passphrase
                        await _showNewPassphraseDialog(vaultKey);
                      } catch (err) {
                        setLocalState(() {
                          isVerifying = false;
                          errorMessage = err.toString().replaceAll("Exception: ", "");
                        });
                      }
                    },
              child: const Text('Verify Code'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewPassphraseDialog(String vaultKey) async {
    final p1Controller = TextEditingController();
    final p2Controller = TextEditingController();
    bool obscure = true;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.green),
              SizedBox(width: 10),
              Text('Set New Passphrase'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Code verified successfully! Enter a new passphrase to protect your vault.\n\nYour vault key will be re-wrapped with Argon2id and your encrypted records will be preserved.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: p1Controller,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'New Passphrase *',
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setLocalState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: p2Controller,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Passphrase *',
                  ),
                ),
                if (isSaving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final p1 = p1Controller.text;
                      final p2 = p2Controller.text;

                      if (p1.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a new passphrase')),
                        );
                        return;
                      }
                      if (p1 != p2) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Passphrases do not match')),
                        );
                        return;
                      }

                      setLocalState(() => isSaving = true);

                      try {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .completeRecoveryWithNewPassphrase(
                              vaultKey: vaultKey,
                              newPassphrase: p1,
                            );

                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passphrase updated and vault unlocked successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (err) {
                        setLocalState(() => isSaving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update passphrase: $err'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: const Text('Save & Unlock Vault'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlassColors.backgroundDark,
      body: GlassBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GlassContainer(
              borderRadius: 28,
              blur: 20,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 36),
              borderColor: Colors.white.withOpacity(0.2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing Balloon / Vault Icon in orange-magenta gradient
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: GlassColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'MYMAIL VAULT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Authenticate to decrypt and view your secure accounts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 34),

                  // Unlock Vault Gradient Button ("let's go!" style)
                  GlassGradientButton(
                    onPressed: () {
                      ref.read(authNotifierProvider.notifier).unlockApp();
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fingerprint_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Unlock Vault',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (_isRequestingRecovery)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF7C3AED),
                      ),
                    )
                  else
                    TextButton.icon(
                      icon: const Icon(
                        Icons.lock_reset_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      label: const Text(
                        'Forgot passphrase?',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: _startForgotPassphraseFlow,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
