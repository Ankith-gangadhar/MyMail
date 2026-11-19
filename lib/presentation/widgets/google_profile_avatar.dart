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

  /// Extracts smart 2-letter initials strictly from the email address
  /// (e.g. "ankithmanjesh@gmail.com" -> "AM", "ankithgangaclassic@gmail.com" -> "AG",
  ///       "ankith.gangadhar@gmail.com" -> "AG", "stream.user@gmail.com" -> "SU")
  /// Label is never used for avatar initials.
  static String getInitials(String email, [String? _]) {
    final clean = email.trim().toLowerCase();
    final localPart = clean.contains('@') ? clean.split('@').first.trim() : clean;
    if (localPart.isEmpty) return 'M';

    // 1. Check delimited by dots, dashes, underscores, plus, or numbers
    // e.g. "ankith.gangadhar@gmail.com" -> "AG", "stream.user@gmail.com" -> "SU"
    final parts = localPart.split(RegExp(r'[._\-+0-9]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }

    // 2. Check camelCase in raw email username (e.g. "AnkithManjesh@gmail.com" -> "AM")
    final rawLocal = email.contains('@') ? email.split('@').first.trim() : email.trim();
    final camelMatches = RegExp(r'[A-Z]').allMatches(rawLocal).map((m) => m.group(0)!).toList();
    if (camelMatches.length >= 2) {
      return (camelMatches[0] + camelMatches[1]).toUpperCase();
    }

    // 3. Smart concatenated name detection for common first-name prefixes
    // e.g. "ankithmanjesh" -> "AM", "ankithgangaclassic" -> "AG", "johnsmith" -> "JS"
    const commonPrefixes = [
      'ankith', 'ankit', 'manjesh', 'gangadhar', 'ganga',
      'rahul', 'rohit', 'varun', 'tarun', 'arun', 'john',
      'alex', 'david', 'priya', 'sneha', 'neha', 'amit',
      'vijay', 'ajay', 'sanjay', 'deepak', 'manoj', 'kiran',
      'karan', 'nikhil', 'prashanth', 'prashant', 'praveen',
      'suresh', 'ramesh', 'mahesh', 'vikram', 'aditya',
      'siddharth', 'sid', 'sam', 'tom', 'dan', 'ben', 'chris',
      'mike', 'steve', 'mark', 'paul', 'james', 'peter'
    ];

    for (final prefix in commonPrefixes) {
      if (localPart.startsWith(prefix) && localPart.length > prefix.length) {
        final remainder = localPart.substring(prefix.length);
        return (prefix[0] + remainder[0]).toUpperCase();
      }
    }

    // 4. Default: first 2 letters of localPart
    if (localPart.length >= 2) {
      return localPart.substring(0, 2).toUpperCase();
    }
    return localPart[0].toUpperCase();
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
    final initials = getInitials(email);
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
