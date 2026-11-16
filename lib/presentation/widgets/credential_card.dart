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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GlassContainer(
        borderRadius: 20,
        blur: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: Colors.white.withOpacity(_isExpanded ? 0.12 : 0.07),
        borderColor: _isExpanded
            ? const Color(0xFFFF7A00).withOpacity(0.4)
            : Colors.white.withOpacity(0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Profile Avatar, Email, and Dropdown toggle
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _toggleExpanded,
              child: Row(
                children: [
                  // Google Profile Photo
                  GoogleProfileAvatar(
                    email: widget.credential.email,
                    size: 42,
                  ),
                  const SizedBox(width: 14),

                  // Email & optional label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.credential.email,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.credential.label != null &&
                            widget.credential.label!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              widget.credential.label!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Dropdown Arrow Button
                  IconButton(
                    icon: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 26,
                      ),
                    ),
                    onPressed: _toggleExpanded,
                    tooltip: _isExpanded ? 'Collapse' : 'Show Password',
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
                    // Frosted Divider
                    Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    const SizedBox(height: 12),

                    // Password Display Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.key_rounded,
                            size: 18,
                            color: Color(0xFFFFB800),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isPasswordVisible
                                  ? widget.credential.password
                                  : '•' * widget.credential.password.length.clamp(8, 16),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _isPasswordVisible ? 15 : 18,
                                letterSpacing: _isPasswordVisible ? 0.5 : 2.5,
                                fontFamily: _isPasswordVisible ? null : 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Toggle Eye Visibility
                          IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 20,
                              color: Colors.white70,
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
                              color: Colors.white70,
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

                    const SizedBox(height: 10),

                    // Quick Actions Row (Copy Email, Edit, Delete)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.email_outlined, size: 16, color: Colors.white70),
                          label: const Text('Copy Email', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white70),
                          label: const Text('Edit', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: widget.onEdit,
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade300),
                          label: Text('Delete', style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
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
