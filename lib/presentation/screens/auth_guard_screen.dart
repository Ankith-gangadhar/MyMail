import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vault_providers.dart';
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

class _VaultLockedView extends ConsumerWidget {
  const _VaultLockedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 54,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'MyMail Vault Locked',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Authenticate to unlock and view your secure accounts',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),
                FilledButton.icon(
                  icon: const Icon(Icons.fingerprint_rounded, size: 22),
                  label: const Text(
                    'Unlock Vault',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).unlockApp();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
