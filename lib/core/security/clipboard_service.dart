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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(message),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          width: 240,
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
