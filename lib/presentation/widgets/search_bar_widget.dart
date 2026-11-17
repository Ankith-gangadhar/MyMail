import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vault_providers.dart';

class VaultSearchBar extends ConsumerStatefulWidget {
  const VaultSearchBar({super.key});

  @override
  ConsumerState<VaultSearchBar> createState() => _VaultSearchBarState();
}

class _VaultSearchBarState extends ConsumerState<VaultSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.72),
                  Colors.white.withOpacity(0.45),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.92),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Color(0xFF121316), fontSize: 14),
              onChanged: (val) {
                ref.read(searchQueryProvider.notifier).setQuery(val);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Search by email or label...',
                hintStyle: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF6B7280),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFFFF5225),
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF6B7280)),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchQueryProvider.notifier).clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
