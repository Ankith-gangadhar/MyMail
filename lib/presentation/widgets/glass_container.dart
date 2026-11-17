import 'dart:ui';
import 'package:flutter/material.dart';

/// Global luxury color palette inspired by the high-end luxury booking & hotel design
/// Soft warm ivory/sand canvas, obsidian charcoal cards, and clean rounded pill geometry
class GlassColors {
  // Luxury Warm Ivory Canvas
  static const Color backgroundIvory = Color(0xFFF4F3EE);
  static const Color backgroundIvoryLight = Color(0xFFFAF9F6);
  static const Color backgroundIvorySurface = Color(0xFFEBE8E1);

  // Legacy alias for backwards compatibility
  static const Color backgroundDark = Color(0xFFF4F3EE);
  static const Color backgroundDeep = Color(0xFFEBE8E1);

  // Obsidian Charcoal for Cards & Dark Elements
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color cardDarkElevated = Color(0xFF262524);
  static const Color cardObsidian = Color(0xFF1E1E1E);

  // Typography
  static const Color textDark = Color(0xFF191817);
  static const Color textMuted = Color(0xFF726F68);
  static const Color textLight = Colors.white;
  static const Color textSilver = Color(0xFFD5D3CB);

  // Warm Champagne Gold & Bronze Accents
  static const Color accentGold = Color(0xFFD4A373);
  static const Color accentWarmBronze = Color(0xFFC59B6D);

  // Primary Obsidian Jet Black Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A2928),
      Color(0xFF161514),
    ],
  );

  // Luxury Warm Champagne Gold Gradient
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFDFB78B),
      Color(0xFFC3965E),
    ],
  );

  // Legacy alias
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A2928),
      Color(0xFF161514),
    ],
  );

  // Inactive surface gradient
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEDEAE2),
      Color(0xFFE4E0D7),
    ],
  );

  // Glass borders and fills
  static Color glassFill = const Color(0xFF1E1E1E);
  static Color glassFillLight = const Color(0xFFFFFFFF);
  static Color glassBorder = Colors.black.withValues(alpha: 0.06);
  static Color glassBorderSubtle = Colors.black.withValues(alpha: 0.04);
  static Color glassBorderActive = const Color(0xFF191817);
}

/// GlassBackground renders the soft warm luxury ivory canvas with subtle organic ambient depth
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GlassColors.backgroundIvory,
      child: Stack(
        children: [
          // Soft warm organic radial gradient in top right
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFEBE5D8).withValues(alpha: 0.8),
                    const Color(0xFFF4F3EE).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Lower left warm sand glow
          Positioned(
            bottom: 40,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFECE6DA).withValues(alpha: 0.7),
                    const Color(0xFFF4F3EE).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Content overlay
          SafeArea(child: child),
        ],
      ),
    );
  }
}

/// Luxury obsidian charcoal card with rounded geometry
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.blur = 16,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? GlassColors.cardObsidian,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}

/// Luxury Obsidian Black / Champagne Gold button
class GlassGradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double height;
  final double? width;
  final double borderRadius;
  final Gradient? gradient;

  const GlassGradientButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.height = 54,
    this.width,
    this.borderRadius = 28,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? const LinearGradient(
                colors: [Color(0xFF88857F), Color(0xFF6B6862)],
              )
            : (gradient ?? GlassColors.primaryGradient),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}
