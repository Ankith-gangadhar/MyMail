import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/credential_entity.dart';
import '../providers/vault_providers.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

    await ref.read(credentialsProvider.notifier).saveCredential(credential);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Credential updated' : 'Credential saved to vault'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final theme = Theme.of(context);
    final isEditing = widget.existingCredential != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  Text(
                    isEditing ? 'Edit Account' : 'Add Account',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Selector
              categoriesAsync.when(
                data: (categories) {
                  final initialVal = categories.any((c) => c.id == _selectedCategoryId)
                      ? _selectedCategoryId
                      : (categories.isNotEmpty ? categories.first.id : null);

                  return DropdownButtonFormField<String>(
                    initialValue: initialVal,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategoryId = val;
                        });
                      }
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => const SizedBox(),
              ),
              const SizedBox(height: 16),

              // Email Input
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email ID *',
                  hintText: 'user@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
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
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      IconButton(
                        tooltip: 'Generate Strong Password',
                        icon: const Icon(Icons.auto_fix_high_rounded),
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
                decoration: const InputDecoration(
                  labelText: 'Label (Optional)',
                  hintText: 'e.g. Primary, Staging, Backup Admin',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // Save Action Button
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Save Account',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
