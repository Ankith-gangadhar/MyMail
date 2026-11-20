import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vault_providers.dart';
import '../widgets/glass_container.dart';
import '../widgets/google_profile_avatar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isProcessingBackup = false;

  Future<void> _startBackupFlow() async {
    final passphraseController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;

    final passphrase = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Create Encrypted Backup', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your backup will be encrypted using AES-256-GCM.\n\nEnter a passphrase to protect your exported file:',
                  style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF5A5852)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passphraseController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Passphrase *',
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setLocalState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Passphrase *',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF726F68))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF191817)),
              onPressed: () {
                final p1 = passphraseController.text;
                final p2 = confirmController.text;
                if (p1.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a passphrase')),
                  );
                  return;
                }
                if (p1 != p2) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Passphrases do not match')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(p1);
              },
              child: const Text('Encrypt & Export'),
            ),
          ],
        ),
      ),
    );

    if (passphrase == null) return;

    setState(() => _isProcessingBackup = true);

    try {
      final repository = ref.read(vaultRepositoryProvider);
      final exportService = ref.read(exportImportServiceProvider);

      final categories = await repository.getCategories();
      final credentials = await repository.getAllCredentials();

      await exportService.exportEncryptedBackup(
        categories: categories,
        credentials: credentials,
        passphrase: passphrase,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Encrypted backup generated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Future<void> _startRestoreFlow() async {
    final passphraseController = TextEditingController();
    bool obscure = true;

    final passphrase = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Restore from Backup', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the passphrase used when creating the backup to decrypt and verify the data:',
                style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF5A5852)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passphraseController,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Backup Passphrase',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setLocalState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF726F68))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF191817)),
              onPressed: () {
                if (passphraseController.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter the passphrase')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(passphraseController.text);
              },
              child: const Text('Select File & Decrypt'),
            ),
          ],
        ),
      ),
    );

    if (passphrase == null) return;

    setState(() => _isProcessingBackup = true);

    try {
      final exportService = ref.read(exportImportServiceProvider);
      final backupData = await exportService.pickAndDecryptBackup(
        passphrase: passphrase,
      );

      if (backupData == null) {
        setState(() => _isProcessingBackup = false);
        return;
      }

      if (!mounted) return;

      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Import Options', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.bold)),
          content: Text(
            'Found ${backupData.credentials.length} accounts and ${backupData.categories.length} categories.\n\nChoose how to import:',
            style: const TextStyle(height: 1.4, color: Color(0xFF5A5852)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('merge'),
              child: const Text('Merge with Existing', style: TextStyle(color: Color(0xFF191817))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.of(ctx).pop('replace'),
              child: const Text('Replace All'),
            ),
          ],
        ),
      );

      if (action == null) {
        setState(() => _isProcessingBackup = false);
        return;
      }

      final repository = ref.read(vaultRepositoryProvider);
      await repository.restoreAll(
        categories: backupData.categories,
        credentials: backupData.credentials,
        replace: action == 'replace',
      );

      // Refresh providers
      await ref.read(categoriesProvider.notifier).loadCategories();
      final currentCat = ref.read(selectedCategoryProvider);
      await ref.read(credentialsProvider.notifier).loadForCategory(currentCat);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully restored ${backupData.credentials.length} accounts (${action == 'replace' ? 'Replaced' : 'Merged'})',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final userEmail = authState.userEmail ?? (authState.isSignedIn ? 'user@gmail.com' : 'guest@local');
    final userLabel = authState.userDisplayName ?? (authState.isSignedIn ? 'MyMail User' : 'Guest');

    return Scaffold(
      backgroundColor: GlassColors.backgroundIvory,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF191817)),
        title: const Text(
          'Settings & Account',
          style: TextStyle(
            color: Color(0xFF191817),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: _isProcessingBackup
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF191817)),
                  SizedBox(height: 16),
                  Text(
                    'Processing backup operation...',
                    style: TextStyle(color: Color(0xFF5A5852)),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Profile Card (Transparent Frosted Glass)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.75),
                            Colors.white.withOpacity(0.45),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.92),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GoogleProfileAvatar(
                            email: userEmail,
                            label: userLabel,
                            photoUrl: authState.userPhotoUrl,
                            size: 52,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userLabel,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF191817),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  userEmail,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF726F68),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5225).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFF5225).withOpacity(0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'Google Account Connected',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF5225),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Security Section
                const Text(
                  'SECURITY & PREFERENCES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Color(0xFF726F68),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.75),
                            Colors.white.withOpacity(0.45),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.92),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.screen_lock_portrait_outlined, color: Color(0xFF191817)),
                            title: const Text('Screen Capture Protection', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.w600)),
                            subtitle: const Text('Blocks screenshots and app switcher recording', style: TextStyle(color: Color(0xFF726F68), fontSize: 12)),
                            value: authState.isScreenCaptureProtectionEnabled,
                            activeColor: const Color(0xFFFF5225),
                            onChanged: (val) {
                              ref.read(authNotifierProvider.notifier).toggleScreenCaptureProtection(val);
                            },
                          ),
                          Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                          ListTile(
                            leading: const Icon(Icons.timer_outlined, color: Color(0xFF191817)),
                            title: const Text('Auto-lock Inactivity Timeout', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              authState.autoLockTimeout == 'immediate'
                                  ? 'Immediate on background'
                                  : authState.autoLockTimeout == '5min'
                                      ? '5 Minutes'
                                      : '1 Minute (Default)',
                              style: const TextStyle(color: Color(0xFF726F68), fontSize: 12),
                            ),
                            trailing: DropdownButton<String>(
                              value: authState.autoLockTimeout,
                              dropdownColor: const Color(0xFFFAF9F6),
                              underline: const SizedBox(),
                              style: const TextStyle(color: Color(0xFF191817)),
                              items: const [
                                DropdownMenuItem(value: 'immediate', child: Text('Immediate')),
                                DropdownMenuItem(value: '1min', child: Text('1 Minute')),
                                DropdownMenuItem(value: '5min', child: Text('5 Minutes')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(authNotifierProvider.notifier).updateAutoLockTimeout(val);
                                }
                              },
                            ),
                          ),
                          Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                          ListTile(
                            leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFF191817)),
                            title: const Text('Lock Vault Now', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.w600)),
                            subtitle: const Text('Lock app with biometric / device lock', style: TextStyle(color: Color(0xFF726F68), fontSize: 12)),
                            onTap: () {
                              ref.read(authNotifierProvider.notifier).lockApp();
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Backup & Restore
                const Text(
                  'BACKUP & RESTORE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Color(0xFF726F68),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.75),
                            Colors.white.withOpacity(0.45),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.92),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.cloud_sync_rounded, color: Color(0xFFFF5225)),
                            title: const Text('Cloud Vault Synchronization', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              authState.isSignedIn
                                  ? 'Active • Synced to $userEmail\nYour data restores automatically if you uninstall or switch phones.'
                                  : 'Sign in to automatically sync and restore your vault across devices.',
                              style: const TextStyle(color: Color(0xFF726F68), fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: authState.isSignedIn ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                authState.isSignedIn ? 'Synced' : 'Local Only',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: authState.isSignedIn ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                ),
                              ),
                            ),
                          ),
                          Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                          ListTile(
                            leading: const Icon(Icons.cloud_download_outlined, color: Color(0xFF191817)),
                            title: const Text('Create Encrypted Backup', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.w600)),
                            subtitle: const Text('Export all categories and accounts safely', style: TextStyle(color: Color(0xFF726F68), fontSize: 12)),
                            onTap: _startBackupFlow,
                          ),
                          Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                          ListTile(
                            leading: const Icon(Icons.restore_page_outlined, color: Color(0xFF191817)),
                            title: const Text('Restore from Backup', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.w600)),
                            subtitle: const Text('Import accounts from an encrypted backup file', style: TextStyle(color: Color(0xFF726F68), fontSize: 12)),
                            onTap: _startRestoreFlow,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Sign Out Button (Glassy Red Pill)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.70),
                              Colors.white.withOpacity(0.45),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: Colors.red.withOpacity(0.35), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                          label: const Text(
                            'Sign Out',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide.none,
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          onPressed: () async {
                            await ref.read(authNotifierProvider.notifier).signOut();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'MyMail Vault • Luxury Edition',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8C8982),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
