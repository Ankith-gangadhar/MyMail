import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/crypto/backup_crypto_service.dart';
import '../../core/security/clipboard_service.dart';
import '../providers/vault_providers.dart';
import '../widgets/glass_container.dart';

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
          title: const Text('Create Encrypted Backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your backup will be strongly encrypted using AES-256-GCM with a key derived via PBKDF2 (100,000 iterations).\n\nEnter a passphrase to protect your backup file:',
                  style: TextStyle(fontSize: 13, height: 1.4),
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
              child: const Text('Cancel'),
            ),
            FilledButton(
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
          title: const Text('Restore from Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the passphrase used when creating the backup to decrypt and verify the data:',
                style: TextStyle(fontSize: 13, height: 1.4),
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
              child: const Text('Cancel'),
            ),
            FilledButton(
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
        // User cancelled file picker
        setState(() => _isProcessingBackup = false);
        return;
      }

      if (!mounted) return;

      // Prompt user whether to Merge or Replace
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Options'),
          content: Text(
            'Found ${backupData.categories.length} categories and ${backupData.credentials.length} accounts in backup.\n\nHow would you like to restore them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('merge'),
              child: const Text('Merge with Existing'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop('replace'),
              child: const Text('Replace Everything'),
            ),
          ],
        ),
      );

      if (action == null || action == 'cancel') {
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
    } on InvalidPassphraseException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect passphrase! Decryption failed.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on CorruptBackupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Corrupt file: ${e.message}'),
            backgroundColor: Colors.red,
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



  Future<void> _downloadOfflineRecoveryKey() async {
    try {
      final key = await ref
          .read(authNotifierProvider.notifier)
          .exportVaultKeyForOfflineBackup();

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.key_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Offline Recovery Key'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is your 256-bit raw Vault Key. Store it securely offline. Anyone with this key can decrypt your vault data:',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  key,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Key'),
              onPressed: () {
                ClipboardService.copy(
                  context: context,
                  text: key,
                  message: 'Vault Key copied to clipboard',
                );
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to retrieve recovery key: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: GlassColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Settings & Security',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: GlassBackground(
        child: _isProcessingBackup
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFF7A00)),
                    SizedBox(height: 16),
                    Text(
                      'Processing cryptographic operation...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  // Google Account Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'GOOGLE ACCOUNT & SYNC',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: GlassContainer(
                      borderRadius: 20,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: GlassColors.primaryGradient,
                              ),
                              child: const Icon(Icons.account_circle, color: Colors.white, size: 22),
                            ),
                            title: const Text('Google Sign-In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text('Sign in with your Google account to sync & backup', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                            trailing: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF8B5CF6)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () async {
                                final recovery = ref.read(recoveryServiceProvider);
                                try {
                                  await recovery.signInWithGoogle();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Signed in with Google successfully'),
                                        backgroundColor: Color(0xFF7C3AED),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Google Sign-In: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Connect', style: TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Security Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'SECURITY & PREFERENCES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: GlassContainer(
                      borderRadius: 20,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.screen_lock_portrait_outlined, color: Colors.white70),
                            title: const Text('Screen Capture Protection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text('Blocks screenshots and app switcher recording', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                            value: authState.isScreenCaptureProtectionEnabled,
                            activeColor: const Color(0xFF7C3AED),
                            onChanged: (val) {
                              ref.read(authNotifierProvider.notifier).toggleScreenCaptureProtection(val);
                            },
                          ),
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                          ListTile(
                            leading: const Icon(Icons.timer_outlined, color: Colors.white70),
                            title: const Text('Auto-lock Inactivity Timeout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              authState.autoLockTimeout == 'immediate'
                                  ? 'Immediate on background'
                                  : authState.autoLockTimeout == '5min'
                                      ? '5 Minutes'
                                      : '1 Minute (Default)',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                            ),
                            trailing: DropdownButton<String>(
                              value: authState.autoLockTimeout,
                              dropdownColor: const Color(0xFF1E1A33),
                              underline: const SizedBox(),
                              style: const TextStyle(color: Colors.white),
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
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                          ListTile(
                            leading: const Icon(Icons.key_rounded, color: Colors.white70),
                            title: const Text('Download recovery key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text('Optional offline copy of your raw 256-bit vault key', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                            trailing: const Icon(Icons.download_rounded, color: Colors.white54),
                            onTap: _downloadOfflineRecoveryKey,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Backup & Restore Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'BACKUP & RESTORE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: GlassContainer(
                      borderRadius: 20,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.cloud_download_outlined, color: Colors.white70),
                            title: const Text('Create Encrypted Backup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              'Export categories & accounts with PBKDF2 passphrase encryption',
                              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                            ),
                            onTap: _startBackupFlow,
                          ),
                          Divider(height: 1, color: Colors.white.withOpacity(0.12)),
                          ListTile(
                            leading: const Icon(Icons.restore_page_outlined, color: Colors.white70),
                            title: const Text('Restore from Backup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              'Import accounts from an encrypted backup file',
                              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                            ),
                            onTap: _startRestoreFlow,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Vault Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'VAULT SPECIFICATIONS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: GlassContainer(
                      borderRadius: 20,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.lock_clock_outlined, color: Colors.white70),
                            title: const Text('Encryption Standard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text('AES-256-GCM + Argon2id Passphrase KDF', style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
                          ),
                          Divider(height: 1, color: Colors.white.withOpacity(0.12)),
                          ListTile(
                            leading: const Icon(Icons.cloud_done_outlined, color: Colors.white70),
                            title: const Text('Recovery Wrap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text('Google Cloud KMS with zero-knowledge passphrase', style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
                          ),
                          Divider(height: 1, color: Colors.white.withOpacity(0.12)),
                          ListTile(
                            leading: const Icon(Icons.lock_reset_outlined, color: Color(0xFFFF5E3A)),
                            title: const Text('Lock Vault Now', style: TextStyle(color: Color(0xFFFF5E3A), fontWeight: FontWeight.bold)),
                            subtitle: Text('Immediately lock vault and purge memory keys', style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
                            onTap: () {
                              ref.read(authNotifierProvider.notifier).lockApp();
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      'MyMail Vault v1.1.0 • Glass Edition',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }
}
