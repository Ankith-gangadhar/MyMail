import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category_entity.dart';
import '../providers/vault_providers.dart';
import 'glass_container.dart';

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
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: orderedList.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == orderedList.length) {
            // Manage categories button
            return ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: Colors.white.withOpacity(0.08),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: onManageCategories,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 16, color: Colors.white70),
                          SizedBox(width: 6),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
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

          final category = orderedList[index];
          final isSelected = selectedCategory == category.id;
          final isPersonal = category.id == 'cat_personal' ||
              category.name.toLowerCase() == 'personal';

          return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    if (isSelected) return;
                    ref.read(authNotifierProvider.notifier).recordActivity();
                    ref.read(selectedCategoryProvider.notifier).selectCategory(category.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: isSelected ? GlassColors.primaryGradient : null,
                      color: isSelected ? null : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF9E00).withOpacity(0.6)
                            : Colors.white.withOpacity(0.15),
                        width: 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF5E3A).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPersonal) ...[
                          Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: isSelected ? Colors.white : const Color(0xFFFF007A),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          category.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
