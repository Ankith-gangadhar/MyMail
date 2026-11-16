import 'dart:ui';
import 'package:flutter/material.dart';

/// Global color palette inspired by Capi Product smart home dark UI
class GlassColors {
  static const Color backgroundDark = Color(0xFF0C0A15);
  static const Color backgroundDeep = Color(0xFF130F22);
  static const Color cardDark = Color(0xFF171427);
  static const Color cardDarkElevated = Color(0xFF1E1A34);

  // Atmospheric Violet & Indigo Illumination
  static const Color orbViolet = Color(0xFF7C3AED);
  static const Color orbIndigo = Color(0xFF4F46E5);
  static const Color orbDeepPurple = Color(0xFF3B1C6E);
  static const Color orbMagenta = Color(0xFF831843);

  // Primary Electric Violet Gradient (matching Capi Product UI)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8B5CF6),
      Color(0xFF6D28D9),
    ],
  );

  // Secondary Accent Gradient (Violet to Magenta)
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFA855F7),
      Color(0xFF7C3AED),
    ],
  );

  // Subtle Indigo/Slate Gradient for inactive/secondary surfaces
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1F1A35),
      Color(0xFF161327),
    ],
  );

  // Glass borders and fills
  static Color glassFill = const Color(0xFF171427).withValues(alpha: 0.85);
  static Color glassFillLight = const Color(0xFF221C38).withValues(alpha: 0.70);
  static Color glassBorder = Colors.white.withValues(alpha: 0.08);
  static Color glassBorderSubtle = Colors.white.withValues(alpha: 0.04);
  static Color glassBorderActive = const Color(0xFF8B5CF6).withValues(alpha: 0.45);
}

/// GlassBackground renders the deep midnight canvas with atmospheric violet & indigo glows
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GlassColors.backgroundDark,
      child: Stack(
        children: [
          // Top right subtle electric violet atmospheric glow
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.28),
                    const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Upper left deep indigo ambient light
          Positioned(
            top: 140,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4338CA).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Center-right deep purple haze
          Positioned(
            top: 360,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6D28D9).withValues(alpha: 0.20),
                    const Color(0xFF831843).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Bottom subtle violet glow
          Positioned(
            bottom: -60,
            left: 20,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF581C87).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Content overlay with subtle blur to blend lights
          SafeArea(child: child),
        ],
      ),
    );
  }
}

/// Frosted dark glass container with subtle border and blur
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
    this.borderRadius = 22,
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
        color: backgroundColor ?? GlassColors.glassFill,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? GlassColors.glassBorder,
          width: 1.1,
        ),
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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      ),
    );
  }
}

/// Electric violet gradient button
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
    this.borderRadius = 27,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? LinearGradient(
                colors: [Colors.grey.shade800, Colors.grey.shade900],
              )
            : (gradient ?? GlassColors.primaryGradient),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
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
