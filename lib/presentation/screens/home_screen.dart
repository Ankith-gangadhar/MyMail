import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/credential_entity.dart';
import '../providers/vault_providers.dart';
import '../widgets/category_chip_bar.dart';
import '../widgets/credential_card.dart';
import '../widgets/glass_container.dart';
import '../widgets/google_profile_avatar.dart';
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

    // Warning & confirmation Dialog
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171427),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Row(
          children: [
            Icon(Icons.share_rounded, color: Color(0xFFA78BFA), size: 24),
            SizedBox(width: 8),
            Text('Export & Share', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Export "${category.name}" credentials (${credentials.length} accounts) to an Excel file and share?',
          style: const TextStyle(height: 1.4, color: Color(0xFFC4BED9)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFB4ACCE))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Share Now'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // Generate Excel and Share directly (no extra biometric prompt needed)
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
        backgroundColor: const Color(0xFF171427),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete the account "${cred.email}"?',
          style: const TextStyle(color: Color(0xFFC4BED9)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFB4ACCE))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
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
      backgroundColor: GlassColors.backgroundDark,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const GoogleProfileAvatar(
                email: 'ankith.gangadhar@gmail.com',
                label: 'Ankith Gangadhar',
                size: 36,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MyMail',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'Vault Active',
                  style: TextStyle(
                    color: Color(0xFFA78BFA),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Share Category action
          IconButton(
            tooltip: 'Export & Share (${currentCategory?.name ?? "Category"})',
            icon: const Icon(Icons.share_outlined, color: Colors.white70),
            onPressed: () {
              if (currentCategory != null) {
                final allCredentials = credentialsAsync.value ?? [];
                _shareCurrentCategory(currentCategory, allCredentials);
              }
            },
          ),
          // Quick Lock Button - side by side with Share
          IconButton(
            tooltip: 'Lock Vault',
            icon: const Icon(Icons.lock_outline, color: Colors.white70),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).lockApp();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: GlassBackground(
        child: Column(
          children: [
            // Categories Chip Bar
            categoriesAsync.when(
              data: (categories) => CategoryChipBar(
                categories: categories,
                onManageCategories: () => CategoryManagementDialog.show(context),
              ),
              loading: () => CategoryChipBar(
                categories: [
                  CategoryEntity(
                    id: 'cat_work',
                    name: 'Work',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                  CategoryEntity(
                    id: 'cat_personal',
                    name: 'Personal',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                ],
                onManageCategories: () => CategoryManagementDialog.show(context),
              ),
              error: (err, st) => CategoryChipBar(
                categories: [
                  CategoryEntity(
                    id: 'cat_work',
                    name: 'Work',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                  CategoryEntity(
                    id: 'cat_personal',
                    name: 'Personal',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                ],
                onManageCategories: () => CategoryManagementDialog.show(context),
              ),
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
                        child: GlassContainer(
                          borderRadius: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: GlassColors.primaryGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.mail_lock_outlined,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No accounts in ${currentCategory?.name ?? 'category'}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the "+" button below to store your first email ID and password securely in your encrypted vault.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.65),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (filteredCredentials.isEmpty) {
                    return Center(
                      child: GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 44,
                              color: Colors.white60,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No matching accounts found',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 90),
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
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Error loading accounts: $err',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: GlassColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              CredentialFormSheet.show(
                context,
                initialCategoryId: selectedCategoryId,
              );
            },
            child: const Icon(Icons.add, size: 30, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
