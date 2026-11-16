import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/security/clipboard_service.dart';
import '../../domain/entities/credential_entity.dart';

class CredentialCard extends StatefulWidget {
  final CredentialEntity credential;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CredentialCard({
    super.key,
    required this.credential,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<CredentialCard> createState() => _CredentialCardState();
}

class _CredentialCardState extends State<CredentialCard> {
  bool _isPasswordVisible = false;
  Timer? _autoMaskTimer;

  @override
  void dispose() {
    _autoMaskTimer?.cancel();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });

    _autoMaskTimer?.cancel();

    // Re-mask automatically after 10 seconds for security
    if (_isPasswordVisible) {
      _autoMaskTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() {
            _isPasswordVisible = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 2 : 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: widget.onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Email ID and Options Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        ClipboardService.copy(
                          context: context,
                          text: widget.credential.email,
                          message: 'Email copied',
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.credential.email,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                letterSpacing: -0.2,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.credential.label != null &&
                                widget.credential.label!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withAlpha(120),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.credential.label!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (val) {
                      if (val == 'edit') {
                        widget.onEdit();
                      } else if (val == 'delete') {
                        widget.onDelete();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                            const SizedBox(width: 10),
                            Text(
                              'Delete',
                              style: TextStyle(color: Colors.red.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.8),
              const SizedBox(height: 10),

              // Password Row: Masked Dots / Readable text, Eye Icon, and Copy Button
              Row(
                children: [
                  Expanded(
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _isPasswordVisible
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Text(
                        '••••••••••••',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: colorScheme.onSurfaceVariant.withAlpha(180),
                        ),
                      ),
                      secondChild: SelectableText(
                        widget.credential.password,
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  // Eye Toggle Button
                  IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
                    onPressed: _togglePasswordVisibility,
                  ),
                  // Copy Password Button
                  IconButton(
                    icon: Icon(
                      Icons.copy_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    tooltip: 'Copy password',
                    onPressed: () {
                      ClipboardService.copy(
                        context: context,
                        text: widget.credential.password,
                        message: 'Password copied',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
