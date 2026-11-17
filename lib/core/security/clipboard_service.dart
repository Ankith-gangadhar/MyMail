import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClipboardService {
  static Timer? _clearTimer;

  /// Copies text to clipboard, displays a short feedback snackbar,
  /// and automatically purges the clipboard after 30 seconds to prevent leaks.
  static Future<void> copy({
    required BuildContext context,
    required String text,
    String message = 'Copied to clipboard',
  }) async {
    _clearTimer?.cancel();

    await Clipboard.setData(ClipboardData(text: text));

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      final bool isEmail = message.toLowerCase().contains('email');
      final bool isPassword = message.toLowerCase().contains('password');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
          padding: EdgeInsets.zero,
          width: 220,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF262529),
                  Color(0xFF161518),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFFFF5225).withOpacity(0.38),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFFFF5225).withOpacity(0.18),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0x28FF5225), // Translucent electric ember orange
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isEmail
                          ? Icons.mark_email_read_rounded
                          : (isPassword ? Icons.vpn_key_rounded : Icons.check_rounded),
                      color: const Color(0xFFFF5225),
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Automatically clear after 30 seconds
    _clearTimer = Timer(const Duration(seconds: 30), () async {
      try {
        final currentData = await Clipboard.getData(Clipboard.kTextPlain);
        // Only clear if the text in clipboard is still the one we copied
        if (currentData?.text == text) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    });
  }

  static void dispose() {
    _clearTimer?.cancel();
    _clearTimer = null;
  }
}
