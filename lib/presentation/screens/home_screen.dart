import 'dart:ui';
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

    // Confirmation Dialog
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Row(
          children: [
            Icon(Icons.share_rounded, color: Color(0xFF191817), size: 24),
            SizedBox(width: 10),
            Text('Export & Share', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Export "${category.name}" credentials (${credentials.length} accounts) to an Excel file and share?',
          style: const TextStyle(height: 1.4, color: Color(0xFF5A5852)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF726F68))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF191817)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Share Now'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Delete Account', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete the account "${cred.email}"?',
          style: const TextStyle(color: Color(0xFF5A5852)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF726F68))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
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
    final authState = ref.watch(authNotifierProvider);
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

    final userEmail = authState.userEmail ?? (authState.isSignedIn ? 'user@gmail.com' : 'guest@local');
    final userLabel = authState.userDisplayName ?? (authState.isSignedIn ? 'MyMail User' : 'Guest');

    return Scaffold(
      backgroundColor: GlassColors.backgroundIvory,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: GoogleProfileAvatar(
                email: userEmail,
                label: userLabel,
                photoUrl: authState.userPhotoUrl,
                size: 38,
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                const Text(
                  'MyMail',
                  style: TextStyle(
                    color: Color(0xFF121316),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: -0.4,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 4, top: 2),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF5225),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Circular Glass Pill for Share
          ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.78),
                      Colors.white.withOpacity(0.45),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.92),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Export & Share (${currentCategory?.name ?? "Category"})',
                  icon: const Icon(Icons.share_outlined, color: Color(0xFF191817), size: 18),
                  onPressed: () {
                    if (currentCategory != null) {
                      final allCredentials = credentialsAsync.value ?? [];
                      _shareCurrentCategory(currentCategory, allCredentials);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Circular Glass Pill for Lock
          ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.78),
                      Colors.white.withOpacity(0.45),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.92),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Lock Vault',
                  icon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF191817), size: 18),
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).lockApp();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: GlassBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Title matching Screen 3 of Booking App
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Passwords',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF191817),
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${filteredCredentials.length} accounts secured in ${currentCategory?.name ?? "Vault"}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF726F68),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Categories Chip Bar (Pill Chips)
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

            // Search Bar (White Rounded Pill)
            const VaultSearchBar(),

            // Accounts List
            Expanded(
              child: credentialsAsync.when(
                data: (allInCat) {
                  if (allInCat.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.70),
                                    Colors.white.withOpacity(0.42),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.90),
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFF5E36),
                                          Color(0xFFFF3310),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFFF8A65),
                                        width: 1.3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF451A).withOpacity(0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.mail_lock_outlined,
                                      size: 34,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'No accounts in ${currentCategory?.name ?? 'category'}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF121316),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tap the "+" button below to store your first email ID and password securely in your vault.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF726F68),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (filteredCredentials.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: Color(0xFF8C8982),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No matching accounts found',
                              style: TextStyle(
                                color: Color(0xFF191817),
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
                    padding: const EdgeInsets.only(top: 4, bottom: 96),
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
                  child: CircularProgressIndicator(color: Color(0xFF191817)),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Error loading accounts: $err',
                    style: const TextStyle(color: Color(0xFF726F68)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        height: 58,
        width: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF5E36),
              Color(0xFFFF3310),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFF8A65),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF451A).withOpacity(0.42),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
            child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
