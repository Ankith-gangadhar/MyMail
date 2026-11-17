import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/credential_entity.dart';
import '../providers/vault_providers.dart';
import '../widgets/glass_container.dart';

class CredentialFormSheet extends ConsumerStatefulWidget {
  final CredentialEntity? existingCredential;
  final String initialCategoryId;

  const CredentialFormSheet({
    super.key,
    this.existingCredential,
    required this.initialCategoryId,
  });

  static Future<void> show(
    BuildContext context, {
    CredentialEntity? credential,
    required String initialCategoryId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => CredentialFormSheet(
        existingCredential: credential,
        initialCategoryId: initialCategoryId,
      ),
    );
  }

  @override
  ConsumerState<CredentialFormSheet> createState() => _CredentialFormSheetState();
}

class _CredentialFormSheetState extends ConsumerState<CredentialFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _labelController;
  late String _selectedCategoryId;
  bool _obscurePassword = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.existingCredential?.email ?? '');
    _passwordController = TextEditingController(text: widget.existingCredential?.password ?? '');
    _labelController = TextEditingController(text: widget.existingCredential?.label ?? '');
    _selectedCategoryId = widget.existingCredential?.categoryId ?? widget.initialCategoryId;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _generateStrongPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_=+';
    final random = Random.secure();
    final pwd = List.generate(18, (index) => chars[random.nextInt(chars.length)]).join();
    setState(() {
      _passwordController.text = pwd;
      _obscurePassword = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final isEditing = widget.existingCredential != null;
    final now = DateTime.now().toUtc();

    final credential = isEditing
        ? widget.existingCredential!.copyWith(
            categoryId: _selectedCategoryId,
            email: _emailController.text.trim(),
            password: _passwordController.text,
            label: _labelController.text.trim().isEmpty ? null : _labelController.text.trim(),
            updatedAt: now,
          )
        : CredentialEntity(
            id: const Uuid().v4(),
            categoryId: _selectedCategoryId,
            email: _emailController.text.trim(),
            password: _passwordController.text,
            label: _labelController.text.trim().isEmpty ? null : _labelController.text.trim(),
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
          );

    try {
      await ref.read(credentialsProvider.notifier).saveCredential(credential);
      // Auto-select category to show saved credential immediately
      ref.read(selectedCategoryProvider.notifier).selectCategory(_selectedCategoryId);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Account updated' : 'Account saved to vault'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF7C3AED),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isEditing = widget.existingCredential != null;

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Color(0xFF726F68), fontSize: 13.5),
      hintStyle: const TextStyle(color: Color(0xFF8C8982), fontSize: 13.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF191817), width: 1.5),
      ),
    );

    final defaultCategories = [
      CategoryEntity(id: 'cat_work', name: 'Work', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      CategoryEntity(id: 'cat_personal', name: 'Personal', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      CategoryEntity(id: 'cat_business', name: 'Business', createdAt: DateTime.now(), updatedAt: DateTime.now()),
    ];

    final availableCategories = categoriesAsync.value?.isNotEmpty == true
        ? categoriesAsync.value!
        : defaultCategories;

    final currentCat = availableCategories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => availableCategories.first,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Account' : 'Add Account',
                        style: const TextStyle(
                          color: Color(0xFF191817),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E5DD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Category: ${currentCat.name}',
                          style: const TextStyle(
                            color: Color(0xFF5A5852),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF726F68)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Email Input
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(color: Color(0xFF191817)),
                decoration: inputDecoration.copyWith(
                  labelText: 'Email ID *',
                  hintText: 'user@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF191817)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter an email ID';
                  }
                  if (!val.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password Input
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Color(0xFF191817)),
                decoration: inputDecoration.copyWith(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF191817)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF726F68),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      IconButton(
                        tooltip: 'Generate Strong Password',
                        icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF191817)),
                        onPressed: _generateStrongPassword,
                      ),
                    ],
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Optional Label Input
              TextFormField(
                controller: _labelController,
                style: const TextStyle(color: Color(0xFF191817)),
                decoration: inputDecoration.copyWith(
                  labelText: 'Label or Account Name (Optional)',
                  hintText: 'e.g. Mangalore Store, Google Workspace',
                  prefixIcon: const Icon(Icons.tag_outlined, color: Color(0xFF191817)),
                ),
              ),
              const SizedBox(height: 26),

              // Save Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF191817),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          isEditing ? 'Save Changes' : 'Save Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
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
