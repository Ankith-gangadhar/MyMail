import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'glass_container.dart';

class GoogleProfileAvatar extends StatelessWidget {
  final String email;
  final String? label;
  final String? photoUrl;
  final double size;

  const GoogleProfileAvatar({
    super.key,
    required this.email,
    this.label,
    this.photoUrl,
    this.size = 44,
  });

  /// Extracts smart 2-letter initials (e.g. "Ankith Gangadhar" -> "AG", "Project Team" -> "PT")
  static String getInitials(String email, [String? label]) {
    // 1. Try from label if available and descriptive
    if (label != null && label.trim().isNotEmpty) {
      final cleanLabel = label.trim();
      final words = cleanLabel.split(RegExp(r'[\s._\-]+')).where((w) => w.isNotEmpty).toList();
      if (words.length >= 2) {
        return (words[0][0] + words[1][0]).toUpperCase();
      }
      // Check camelCase (e.g. "ProjectTeam")
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

      // Check compound keywords like "ankithgangadhar"
      final lower = localPart.toLowerCase();
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
    // Only use explicit photoUrl (e.g. from logged-in Google account in top app bar)
    // Never fall back to currentUser for credential cards
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return photoUrl!.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final initials = getInitials(email, label);
    final photo = _photoUrl;

    Widget monogramWidget = Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF262529),
            Color(0xFF141316),
          ],
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.38,
          letterSpacing: 0.5,
        ),
      ),
    );

    Widget avatarContent;
    if (photo != null && photo.isNotEmpty) {
      avatarContent = Stack(
        fit: StackFit.expand,
        children: [
          monogramWidget,
          Image.network(
            photo,
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (context, error, stackTrace) => monogramWidget,
          ),
        ],
      );
    } else {
      avatarContent = monogramWidget;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFF5225).withOpacity(0.50),
          width: 1.2,
        ),
      ),
      child: ClipOval(child: avatarContent),
    );
  }
}
