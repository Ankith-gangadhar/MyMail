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

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Add Category', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Color(0xFF191817)),
          decoration: InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Finance, Shopping, Crypto',
            filled: true,
            fillColor: const Color(0xFFFAF9F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF726F68))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF191817),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                ref.read(categoriesProvider.notifier).addCategory(name, false);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(CategoryEntity category) async {
    final nameController = TextEditingController(text: category.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Rename Category', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Color(0xFF191817)),
          decoration: InputDecoration(
            labelText: 'New Name',
            filled: true,
            fillColor: const Color(0xFFFAF9F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF726F68))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF191817),
            ),
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                ref.read(categoriesProvider.notifier).renameCategory(category.id, newName);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(CategoryEntity category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Category', style: TextStyle(color: Color(0xFF191817), fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${category.name}" and all its stored accounts?',
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
      await ref.read(categoriesProvider.notifier).deleteCategory(category.id);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Dialog(
      backgroundColor: const Color(0xFFFAF9F6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Manage Categories',
                    style: TextStyle(
                      color: Color(0xFF191817),
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
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
                        color: const Color(0xFFFF855F),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF451A).withOpacity(0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Add Category',
                      icon: const Icon(Icons.add, size: 20, color: Colors.white),
                      onPressed: _showAddCategoryDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: Colors.black.withOpacity(0.06)),

              // Categories Reorderable List
              SizedBox(
                height: 320,
                child: categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Center(
                        child: Text(
                          'No categories available',
                          style: TextStyle(color: Color(0xFF8C8982)),
                        ),
                      );
                    }

                    return ReorderableListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      onReorder: (oldIndex, newIndex) {
                        ref.read(categoriesProvider.notifier).reorderCategories(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isDefault = cat.id == 'cat_work' || cat.id == 'cat_personal';

                        return Container(
                          key: ValueKey(cat.id),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F3EE),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black.withOpacity(0.04)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.drag_indicator_rounded,
                                color: Color(0xFF8C8982),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(
                                    color: Color(0xFF191817),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 19),
                                    color: const Color(0xFF5A5852),
                                    onPressed: () => _showRenameDialog(cat),
                                  ),
                                  if (!isDefault)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 19),
                                      color: Colors.red.shade600,
                                      onPressed: () => _confirmDelete(cat),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF191817)),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF5E36),
                        Color(0xFFFF3310),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF855F),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF451A).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
