import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category_entity.dart';
import '../providers/vault_providers.dart';

class CategoryManagementDialog extends ConsumerStatefulWidget {
  const CategoryManagementDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const CategoryManagementDialog(),
    );
  }

  @override
  ConsumerState<CategoryManagementDialog> createState() => _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends ConsumerState<CategoryManagementDialog> {
  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    bool isLocked = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Finance, Shopping',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Require Lock'),
                subtitle: const Text('Authenticate before viewing'),
                value: isLocked,
                onChanged: (val) {
                  setLocalState(() => isLocked = val);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  ref.read(categoriesProvider.notifier).addCategory(name, isLocked);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(CategoryEntity category) async {
    final nameController = TextEditingController(text: category.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                ref.read(categoriesProvider.notifier).renameCategory(category.id, newName);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategoryWithAuth(CategoryEntity category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text(
          'Deleting this category will also remove all its stored accounts. This action requires device authentication.',
        ),
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

    if (confirmed != true) return;

    final biometricService = ref.read(biometricServiceProvider);
    final authenticated = await biometricService.authenticate(
      localizedReason: 'Authenticate to confirm deletion of category "${category.name}"',
    );

    if (authenticated) {
      await ref.read(categoriesProvider.notifier).deleteCategory(category.id);
      // Reset selected category to Work if the deleted one was selected
      final selectedId = ref.read(selectedCategoryProvider);
      if (selectedId == category.id) {
        ref.read(selectedCategoryProvider.notifier).selectCategory('cat_work');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "${category.name}" deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Category was not deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Manage Categories'),
          IconButton(
            tooltip: 'Add Category',
            icon: const Icon(Icons.add),
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return const Center(child: Text('No categories available'));
            }

            return ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: categories.length,
              onReorderItem: (oldIndex, newIndex) {
                ref.read(categoriesProvider.notifier).reorderCategories(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isDefaultWork = cat.id == 'cat_work';
                final isDefaultPersonal = cat.id == 'cat_personal';

                return ListTile(
                  key: ValueKey(cat.id),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.drag_indicator, color: Colors.grey),
                  title: Text(
                    cat.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    cat.isLocked ? 'Locked (Requires Auth)' : 'Unlocked',
                    style: TextStyle(
                      fontSize: 12,
                      color: cat.isLocked ? Colors.amber.shade800 : Colors.green.shade700,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Lock toggle
                      IconButton(
                        tooltip: cat.isLocked ? 'Disable Lock' : 'Enable Lock',
                        icon: Icon(
                          cat.isLocked ? Icons.lock_outline : Icons.lock_open_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          ref.read(categoriesProvider.notifier).toggleCategoryLock(
                                cat.id,
                                !cat.isLocked,
                              );
                        },
                      ),
                      // Rename
                      IconButton(
                        tooltip: 'Rename',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showRenameDialog(cat),
                      ),
                      // Delete (protected)
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: (isDefaultWork || isDefaultPersonal)
                              ? Colors.grey.shade400
                              : Colors.red.shade400,
                        ),
                        onPressed: () => _deleteCategoryWithAuth(cat),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
