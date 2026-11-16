import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'glass_container.dart';

class GoogleProfileAvatar extends StatelessWidget {
  final String email;
  final double size;

  const GoogleProfileAvatar({
    super.key,
    required this.email,
    this.size = 44,
  });

  String get _avatarUrl {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          currentUser.email?.toLowerCase().trim() == email.toLowerCase().trim() &&
          currentUser.photoURL != null &&
          currentUser.photoURL!.isNotEmpty) {
        return currentUser.photoURL!;
      }
    } catch (_) {}
    // Unavatar endpoint attempts Google profile picture first, then Gravatar, then initial letter
    return 'https://unavatar.io/google/${email.trim()}?fallback=https://ui-avatars.com/api/?name=${Uri.encodeComponent(email)}&background=7928CA&color=fff&bold=true';
  }

  @override
  Widget build(BuildContext context) {
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'M';
    final isGmail = email.toLowerCase().endsWith('@gmail.com');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isGmail
            ? GlassColors.primaryGradient
            : GlassColors.purpleGradient,
        boxShadow: [
          BoxShadow(
            color: (isGmail ? const Color(0xFFFF5E3A) : const Color(0xFF7928CA))
                .withOpacity(0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          _avatarUrl,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) {
            // Stylish fallback: Initial letter or Google G badge
            return Container(
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.44,
                  shadows: const [
                    Shadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.44,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
