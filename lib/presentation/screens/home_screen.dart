import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/credential_entity.dart';
import '../providers/vault_providers.dart';
import '../widgets/category_chip_bar.dart';
import '../widgets/credential_card.dart';
import '../widgets/search_bar_widget.dart';
import 'category_management_dialog.dart';
import 'credential_form_sheet.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _shareCurrentCategory(
    CategoryEntity category,
    List<CredentialEntity> credentials,
  ) async {
    // Sharing Personal category is strictly prohibited
    if (category.id == 'cat_personal' ||
        category.name.trim().toLowerCase() == 'personal') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personal category cannot be exported to an unencrypted file.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (credentials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No accounts in this category to export.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Step 1: Warning Dialog
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            SizedBox(width: 8),
            Text('Export Warning'),
          ],
        ),
        content: const Text(
          'The exported Excel file contains passwords in readable form. Share it only with people you trust.\n\nYou must authenticate to proceed.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Authenticate & Share'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // Step 2: Fresh Biometric / Device Authentication
    final biometricService = ref.read(biometricServiceProvider);
    final authenticated = await biometricService.authenticate(
      localizedReason: 'Authenticate to export passwords to Excel',
    );

    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Export aborted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Step 3: Generate Excel and Share
    try {
      final exportService = ref.read(exportImportServiceProvider);
      await exportService.shareCategoryAsExcel(
        category: category,
        credentials: credentials,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteCredential(CredentialEntity cred) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Are you sure you want to delete the account "${cred.email}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(credentialsProvider.notifier).deleteCredential(cred.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategoryId = ref.watch(selectedCategoryProvider);
    final filteredCredentials = ref.watch(filteredCredentialsProvider);
    final credentialsAsync = ref.watch(credentialsProvider);

    // Find current category entity
    final currentCategory = categoriesAsync.value?.firstWhere(
      (c) => c.id == selectedCategoryId,
      orElse: () => CategoryEntity(
        id: selectedCategoryId,
        name: 'Work',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final isPersonalCategory = currentCategory != null &&
        (currentCategory.id == 'cat_personal' ||
            currentCategory.name.trim().toLowerCase() == 'personal');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.shield_outlined, size: 22, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            const Text('MyMail'),
          ],
        ),
        actions: [
          // Share Category action - Strictly hidden for Personal category
          if (!isPersonalCategory && currentCategory != null)
            IconButton(
              tooltip: 'Export & Share (${currentCategory.name})',
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                final allCredentials = credentialsAsync.value ?? [];
                _shareCurrentCategory(currentCategory, allCredentials);
              },
            ),
          // Settings Action
          IconButton(
            tooltip: 'Settings & Backup',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          // Quick Lock Button
          IconButton(
            tooltip: 'Lock Vault',
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).lockApp();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Categories Chip Bar
          categoriesAsync.when(
            data: (categories) => CategoryChipBar(
              categories: categories,
              onManageCategories: () => CategoryManagementDialog.show(context),
            ),
            loading: () => const SizedBox(height: 48),
            error: (err, st) => const SizedBox(),
          ),

          // Search Bar
          const VaultSearchBar(),

          // Accounts List
          Expanded(
            child: credentialsAsync.when(
              data: (allInCat) {
                if (allInCat.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mail_lock_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withAlpha(100),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No accounts in ${currentCategory?.name ?? 'category'}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the "+" button below to store your first email ID and password securely.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withAlpha(160),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (filteredCredentials.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withAlpha(120),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No matching accounts found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 84),
                  itemCount: filteredCredentials.length,
                  itemBuilder: (context, index) {
                    final credential = filteredCredentials[index];
                    return CredentialCard(
                      credential: credential,
                      onEdit: () {
                        CredentialFormSheet.show(
                          context,
                          credential: credential,
                          initialCategoryId: selectedCategoryId,
                        );
                      },
                      onDelete: () => _confirmDeleteCredential(credential),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading accounts: $err'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Account',
        onPressed: () {
          CredentialFormSheet.show(
            context,
            initialCategoryId: selectedCategoryId,
          );
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
