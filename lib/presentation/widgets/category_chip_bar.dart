import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category_entity.dart';
import '../providers/vault_providers.dart';

class CategoryChipBar extends ConsumerWidget {
  final List<CategoryEntity> categories;
  final VoidCallback onManageCategories;

  const CategoryChipBar({
    super.key,
    required this.categories,
    required this.onManageCategories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final authState = ref.watch(authNotifierProvider);

    // Arrange categories:
    // 1. Work category first
    // 2. Custom categories in sort order
    // 3. Personal category placed at the end with lock icon
    final now = DateTime.now();
    final workCategory = categories.firstWhere(
      (c) => c.name.toLowerCase() == 'work' || c.id == 'cat_work',
      orElse: () => categories.isNotEmpty
          ? categories.first
          : CategoryEntity(
              id: 'cat_work',
              name: 'Work',
              createdAt: now,
              updatedAt: now,
            ),
    );

    final personalCategory = categories.firstWhere(
      (c) => c.name.toLowerCase() == 'personal' || c.id == 'cat_personal',
      orElse: () => CategoryEntity(
        id: 'cat_personal',
        name: 'Personal',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final middleCategories = categories.where((c) {
      final name = c.name.toLowerCase();
      final id = c.id;
      return name != 'work' && id != 'cat_work' && name != 'personal' && id != 'cat_personal';
    }).toList();

    final orderedList = <CategoryEntity>[];
    if (categories.any((c) => c.id == workCategory.id)) {
      orderedList.add(workCategory);
    }
    orderedList.addAll(middleCategories);
    if (categories.any((c) => c.id == personalCategory.id)) {
      orderedList.add(personalCategory);
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: orderedList.length + 1, // +1 for Manage Categories action
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == orderedList.length) {
            // Manage categories button at the end
            return ActionChip(
              avatar: const Icon(Icons.tune, size: 16),
              label: const Text('Categories'),
              onPressed: onManageCategories,
            );
          }

          final category = orderedList[index];
          final isSelected = selectedCategory == category.id;
          final isPersonal = category.id == 'cat_personal' ||
              category.name.toLowerCase() == 'personal';
          final isUnlocked = authState.unlockedCategoryIds.contains(category.id);

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: isPersonal
                ? Icon(
                    isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                    size: 16,
                    color: isSelected ? Colors.white : Colors.amber.shade700,
                  )
                : category.isLocked
                    ? Icon(
                        isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        size: 15,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      )
                    : null,
            label: Text(category.name),
            labelStyle: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : null,
            ),
            selectedColor: Theme.of(context).colorScheme.primary,
            onSelected: (selected) async {
              if (isSelected) return;

              // Check if category requires authentication
              if (category.isLocked && !isUnlocked) {
                final success = await ref
                    .read(authNotifierProvider.notifier)
                    .unlockCategory(category.id);
                if (!success) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Authentication required to open this category'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                }
              }

              ref.read(selectedCategoryProvider.notifier).selectCategory(category.id);
            },
          );
        },
      ),
    );
  }
}
