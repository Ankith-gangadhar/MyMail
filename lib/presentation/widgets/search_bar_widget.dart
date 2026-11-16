import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vault_providers.dart';
import 'glass_container.dart';

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: GlassContainer(
        borderRadius: 18,
        blur: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        backgroundColor: Colors.white.withOpacity(0.08),
        borderColor: Colors.white.withOpacity(0.18),
        child: TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (val) {
            ref.read(searchQueryProvider.notifier).setQuery(val);
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: 'Search by email or label...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.45),
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: Colors.white.withOpacity(0.7),
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.white70),
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
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}
