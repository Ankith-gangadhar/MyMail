import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/crypto/backup_crypto_service.dart';
import '../providers/vault_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isProcessingBackup
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing cryptographic operation...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // Security Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'SECURITY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: const Text('Device Lock Protection'),
                        subtitle: const Text('Biometrics & Device Credentials active'),
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Auto-lock Inactivity Timeout'),
                        subtitle: Text(
                          authState.autoLockTimeout == 'immediate'
                              ? 'Immediate on background'
                              : authState.autoLockTimeout == '5min'
                                  ? '5 Minutes'
                                  : '1 Minute (Default)',
                        ),
                        trailing: DropdownButton<String>(
                          value: authState.autoLockTimeout,
                          underline: const SizedBox(),
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
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.screen_lock_portrait_outlined),
                        title: const Text('Screen Capture Protection'),
                        subtitle: const Text('FLAG_SECURE blocks screenshots and recents preview'),
                        trailing: const Icon(Icons.lock, size: 18),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Backup & Restore Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'BACKUP & RESTORE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.cloud_download_outlined),
                        title: const Text('Create Encrypted Backup'),
                        subtitle: const Text(
                          'Export all categories and accounts protected by a passphrase',
                        ),
                        onTap: _startBackupFlow,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.restore_page_outlined),
                        title: const Text('Restore from Backup'),
                        subtitle: const Text(
                          'Import accounts from a previous encrypted backup file',
                        ),
                        onTap: _startRestoreFlow,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Vault Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'VAULT SPECIFICATIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.lock_clock_outlined),
                        title: Text('Encryption standard'),
                        subtitle: Text('AES-256-GCM (Authenticated Encryption)'),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.key_outlined),
                        title: Text('Key Storage'),
                        subtitle: Text('Android Keystore hardware-backed secure storage'),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.wifi_off_outlined),
                        title: Text('Network Connectivity'),
                        subtitle: Text('100% Offline Vault • Zero network permissions'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_reset_outlined, color: Colors.orange),
                        title: const Text('Lock Vault Now'),
                        subtitle: const Text('Immediately lock and require authentication'),
                        onTap: () {
                          ref.read(authNotifierProvider.notifier).lockApp();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'MyMail Vault v1.0.0 (Phase 1)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
