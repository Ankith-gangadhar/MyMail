import 'dart:ui';
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: orderedList.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == orderedList.length) {
            // Manage/Edit categories button (transparent glassy pill)
            return ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: onManageCategories,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.45),
                            const Color(0xFFE8E5DD).withOpacity(0.40),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.70),
                          width: 1.1,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 16, color: Color(0xFF5A5852)),
                          SizedBox(width: 6),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: Color(0xFF5A5852),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.80),
                                Colors.white.withOpacity(0.50),
                              ],
                            )
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.35),
                                const Color(0xFFE8E5DD).withOpacity(0.40),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white.withOpacity(0.95)
                            : Colors.white.withOpacity(0.55),
                        width: isSelected ? 1.3 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
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
                          color: isSelected ? const Color(0xFF191817) : const Color(0xFF6E6B65),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13.5,
                          letterSpacing: -0.1,
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
