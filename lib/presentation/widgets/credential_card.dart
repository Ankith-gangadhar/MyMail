import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/security/clipboard_service.dart';
import '../../domain/entities/credential_entity.dart';
import 'glass_container.dart';
import 'google_profile_avatar.dart';

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

class _CredentialCardState extends State<CredentialCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isPasswordVisible = false;
  Timer? _autoMaskTimer;

  @override
  void dispose() {
    _autoMaskTimer?.cancel();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
        _isPasswordVisible = false;
        _autoMaskTimer?.cancel();
      }
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });

    _autoMaskTimer?.cancel();

    // Re-mask automatically after 10 seconds for privacy
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Avatar, Label, and Dropdown toggle
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _toggleExpanded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Google Profile Photo or Smart Initials
                      GoogleProfileAvatar(
                        email: widget.credential.email,
                        label: widget.credential.label,
                        size: 36,
                      ),
                      const SizedBox(width: 12),

                      // Optional Label / Name beside avatar
                      Expanded(
                        child: Text(
                          (widget.credential.label != null &&
                                  widget.credential.label!.trim().isNotEmpty &&
                                  widget.credential.label!.trim().toLowerCase() !=
                                      widget.credential.email.trim().toLowerCase())
                              ? widget.credential.label!.trim()
                              : 'Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Floating circular pill toggle
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.12),
                        ),
                        child: AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Dedicated Full-Width Email Line directly below avatar & header area
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282828),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.credential.email,
                        style: const TextStyle(
                          color: Color(0xFFEBE8E1),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Dropdown content: Only visible when expanded
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Divider
                    Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.08),
                    ),
                    const SizedBox(height: 12),

                    // Password Display Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.key_rounded,
                            size: 18,
                            color: Color(0xFFD4A373), // Subtle champagne gold
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isPasswordVisible
                                  ? widget.credential.password
                                  : '••••••••••',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _isPasswordVisible ? 15 : 18,
                                letterSpacing: _isPasswordVisible ? 0.5 : 3.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // Toggle Eye Visibility
                          IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 20,
                              color: const Color(0xFFB4B0A7),
                            ),
                            tooltip: _isPasswordVisible
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: _togglePasswordVisibility,
                          ),
                          // Copy Password button
                          IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: Color(0xFFB4B0A7),
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
                    ),

                    const SizedBox(height: 12),

                    // Quick Actions Row (Copy Email, Edit, Delete)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.email_outlined, size: 16, color: Color(0xFFD5D3CB)),
                          label: const Text('Copy Email', style: TextStyle(color: Color(0xFFD5D3CB), fontSize: 12.5)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: () {
                            ClipboardService.copy(
                              context: context,
                              text: widget.credential.email,
                              message: 'Email copied',
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFD5D3CB)),
                          label: const Text('Edit', style: TextStyle(color: Color(0xFFD5D3CB), fontSize: 12.5)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: widget.onEdit,
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade300),
                          label: Text('Delete', style: TextStyle(color: Colors.red.shade300, fontSize: 12.5)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: widget.onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}
