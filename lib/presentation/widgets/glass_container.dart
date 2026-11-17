import 'dart:ui';
import 'package:flutter/material.dart';

/// Global color palette inspired by the futuristic Steel Grey, Deep Charcoal & Electric Ember Orange design
class GlassColors {
  // Cool Futuristic Steel Grey Canvas
  static const Color backgroundGrey = Color(0xFFE5E7EB);
  static const Color backgroundGreyLight = Color(0xFFEDEFF3);
  static const Color backgroundIvory = Color(0xFFE5E7EB);
  static const Color backgroundIvoryLight = Color(0xFFEDEFF3);
  static const Color backgroundIvorySurface = Color(0xFFDDE0E7);

  // Legacy alias for backwards compatibility
  static const Color backgroundDark = Color(0xFFE5E7EB);
  static const Color backgroundDeep = Color(0xFFDDE0E7);

  // Deep Charcoal & Obsidian for Cards & Dark Elements
  static const Color cardDark = Color(0xFF1A1C21);
  static const Color cardDarkElevated = Color(0xFF23252C);
  static const Color cardObsidian = Color(0xFF18191E);
  static const Color cardCharcoal = Color(0xFF1A1C21);

  // Typography
  static const Color textDark = Color(0xFF121316);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textLight = Colors.white;
  static const Color textSilver = Color(0xFFD3D6DE);

  // Vibrant Electric Ember Orange Accents
  static const Color accentOrange = Color(0xFFFF5225);
  static const Color accentOrangeGlow = Color(0xFFFF6E40);
  static const Color accentOrangeDark = Color(0xFFFF3310);
  static const Color accentGold = Color(0xFFFF5225);
  static const Color accentWarmBronze = Color(0xFFFF6E40);

  // Vibrant Electric Orange Gradient
  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF5E36),
      Color(0xFFFF3310),
    ],
  );

  // Primary Shiny Charcoal Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2D2F37),
      Color(0xFF1A1B20),
      Color(0xFF101114),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Shiny Charcoal Gradient for Cards
  static const LinearGradient shinyObsidianGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF262830),
      Color(0xFF18191E),
      Color(0xFF101114),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  // Transparent Glassy White Gradient
  static const LinearGradient glassWhiteGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xB3FFFFFF), // ~70% white
      Color(0x66FFFFFF), // ~40% white
    ],
  );

  // Electric Orange Glow Gradient
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF6E40),
      Color(0xFFFF3D00),
    ],
  );

  // Legacy alias
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF262830),
      Color(0xFF101114),
    ],
  );

  // Inactive surface gradient
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x66DDE0E7),
      Color(0x40DDE0E7),
    ],
  );

  // Glass borders and fills
  static Color glassFill = const Color(0xFF1A1C21);
  static Color glassFillLight = Colors.white.withOpacity(0.60);
  static Color glassBorder = Colors.white.withOpacity(0.85);
  static Color glassBorderSubtle = Colors.white.withOpacity(0.50);
  static Color glassBorderActive = const Color(0xFFFF5225);
  static Color shinyBorder = Colors.white.withOpacity(0.14);
}

/// GlassBackground renders the cool steel grey canvas with radiant ember/orange ambient light
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GlassColors.backgroundGrey,
      child: Stack(
        children: [
          // Top right subtle cool steel aura
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFCAD0DC).withOpacity(0.6),
                    const Color(0xFFE5E7EB).withOpacity(0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Lower left radiant ember orange glow (signature futuristic aesthetic)
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF5225).withOpacity(0.38),
                    const Color(0xFFFF6E40).withOpacity(0.18),
                    const Color(0xFFE5E7EB).withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Lower right secondary ambient warm glow
          Positioned(
            bottom: 120,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF3D00).withOpacity(0.20),
                    const Color(0xFFE5E7EB).withOpacity(0.0),
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

/// Luxury obsidian shiny card or frosted white glass container
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
  final Gradient? gradient;
  final bool isGlassLight;
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
    this.gradient,
    this.isGlassLight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = Border.all(
      color: borderColor ??
          (isGlassLight
              ? Colors.white.withOpacity(0.85)
              : Colors.white.withOpacity(0.14)),
      width: 1.2,
    );

    final effectiveGradient = gradient ??
        (isGlassLight
            ? GlassColors.glassWhiteGradient
            : (backgroundColor == null ? GlassColors.shinyObsidianGradient : null));

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: effectiveGradient == null ? (backgroundColor ?? GlassColors.cardObsidian) : null,
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorder,
        boxShadow: isGlassLight
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF100F0F).withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.04),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: isGlassLight
          ? child
          : Stack(
              children: [
                // Top specular sheen reflection for shiny obsidian finish
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
    );

    if (isGlassLight) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

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

/// Luxury Shiny Obsidian Black / Champagne Gold button
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
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
          width: 1.2,
        ),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 16,
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
