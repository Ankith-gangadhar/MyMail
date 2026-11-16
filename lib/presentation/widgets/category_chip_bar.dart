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
    orderedList.add(workCategory);
    for (final c in middleCategories) {
      if (!orderedList.any((existing) => existing.id == c.id)) {
        orderedList.add(c);
      }
    }
    if (!orderedList.any((c) => c.id == personalCategory.id)) {
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
                  color: const Color(0xFF1E1A33).withValues(alpha: 0.7),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: onManageCategories,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 16, color: Color(0xFFC4BED9)),
                          SizedBox(width: 6),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: Color(0xFFC4BED9),
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
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      gradient: isSelected ? GlassColors.primaryGradient : null,
                      color: isSelected ? null : const Color(0xFF1C1830).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFA78BFA).withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08),
                        width: 1.1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFB4ACCE),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
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
