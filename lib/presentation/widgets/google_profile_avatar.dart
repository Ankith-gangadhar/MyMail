import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'glass_container.dart';

class GoogleProfileAvatar extends StatelessWidget {
  final String email;
  final String? label;
  final double size;

  const GoogleProfileAvatar({
    super.key,
    required this.email,
    this.label,
    this.size = 44,
  });

  /// Extracts smart 2-letter initials (e.g. "Ankith Gangadhar" -> "AG", "Mangalore Store" -> "MS")
  static String getInitials(String email, [String? label]) {
    // 1. Try from label if available and descriptive
    if (label != null && label.trim().isNotEmpty) {
      final cleanLabel = label.trim();
      final words = cleanLabel.split(RegExp(r'[\s._\-]+')).where((w) => w.isNotEmpty).toList();
      if (words.length >= 2) {
        return (words[0][0] + words[1][0]).toUpperCase();
      }
      // Check camelCase (e.g. "MangaloreStore")
      final camelMatches = RegExp(r'[A-Z]').allMatches(cleanLabel).map((m) => m.group(0)!).toList();
      if (camelMatches.length >= 2) {
        return (camelMatches[0] + camelMatches[1]).toUpperCase();
      }
      if (cleanLabel.length >= 2) {
        return cleanLabel.substring(0, 2).toUpperCase();
      }
    }

    // 2. Try from email address username
    final localPart = email.split('@').first.trim();
    if (localPart.isNotEmpty) {
      // Check delimited by dots, dashes, underscores (e.g. ankith.gangadhar -> AG)
      final parts = localPart.split(RegExp(r'[._\-]')).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }

      // Check compound keywords like "mangalorestore" or "ankithgangadhar"
      final lower = localPart.toLowerCase();
      if (lower.contains('mangalore') && lower.contains('store')) {
        return 'MS';
      }
      if (lower.contains('ankith') && lower.contains('gangadhar')) {
        return 'AG';
      }

      // Check camelCase in email
      final camelMatches = RegExp(r'[A-Z]').allMatches(localPart).map((m) => m.group(0)!).toList();
      if (camelMatches.length >= 2) {
        return (camelMatches[0] + camelMatches[1]).toUpperCase();
      }

      if (localPart.length >= 2) {
        return localPart.substring(0, 2).toUpperCase();
      }
      return localPart[0].toUpperCase();
    }

    return 'M';
  }

  String? get _photoUrl {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          currentUser.email?.toLowerCase().trim() == email.toLowerCase().trim() &&
          currentUser.photoURL != null &&
          currentUser.photoURL!.isNotEmpty) {
        return currentUser.photoURL;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final initials = getInitials(email, label);
    final photo = _photoUrl;

    Widget avatarContent = Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: GlassColors.primaryGradient,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.40,
          letterSpacing: 0.5,
          shadows: const [
            Shadow(color: Colors.black45, blurRadius: 4),
          ],
        ),
      ),
    );

    if (photo != null) {
      avatarContent = Image.network(
        photo,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) => avatarContent,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1.4,
        ),
      ),
      child: ClipOval(child: avatarContent),
    );
  }
}
