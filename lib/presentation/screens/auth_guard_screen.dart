import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vault_providers.dart';
import '../widgets/glass_container.dart';
import 'home_screen.dart';
import 'login_screen.dart';

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
        AuthStatus.unauthenticated => const LoginScreen(),
        AuthStatus.deviceSecurityMissing => const _DeviceSecurityMissingView(),
        AuthStatus.locked => const _VaultLockedView(),
        AuthStatus.authenticated => const HomeScreen(),
        _ => const Scaffold(
            backgroundColor: GlassColors.backgroundIvory,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF191817)),
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
    return Scaffold(
      backgroundColor: GlassColors.backgroundIvory,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.gpp_bad_rounded,
                  size: 46,
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Device Screen Lock Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191817),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'To secure your encrypted email accounts, please enable a PIN, pattern, or biometric lock in your device Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF726F68),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF191817),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).initialize();
                  },
                  child: const Text('Try Again'),
                ),
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
    return Scaffold(
      backgroundColor: GlassColors.backgroundIvory,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock Icon Badge
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: const Color(0xFF191817),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Vault Locked',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191817),
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Authenticate to view your accounts',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF726F68),
                  ),
                ),
                const SizedBox(height: 36),

                // Unlock Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.fingerprint_rounded, size: 22),
                    label: const Text(
                      'Unlock Vault',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF191817),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      ref.read(authNotifierProvider.notifier).unlockApp();
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Sign in with another account
                TextButton(
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).signOut();
                  },
                  child: const Text(
                    'Switch Account / Sign In',
                    style: TextStyle(
                      color: Color(0xFF191817),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
