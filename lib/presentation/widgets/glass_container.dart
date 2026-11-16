import 'dart:ui';
import 'package:flutter/material.dart';

/// Global glassmorphism color palette inspired by reference layout
class GlassColors {
  static const Color backgroundDark = Color(0xFF0F0C20);
  static const Color backgroundDeep = Color(0xFF15122E);
  
  // Glowing orb gradients
  static const Color orbOrange = Color(0xFFFF7A00);
  static const Color orbPink = Color(0xFFFF007A);
  static const Color orbPurple = Color(0xFF7928CA);
  static const Color orbCyan = Color(0xFF00DFD8);
  static const Color orbGold = Color(0xFFFFB800);

  // Gradient for primary buttons ("let's go!" style)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFF9E00),
      Color(0xFFFF007A),
    ],
  );

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7928CA),
      Color(0xFFFF0080),
    ],
  );

  // Glass borders and fills
  static Color glassFill = Colors.white.withOpacity(0.08);
  static Color glassFillLight = Colors.white.withOpacity(0.14);
  static Color glassBorder = Colors.white.withOpacity(0.18);
  static Color glassBorderSubtle = Colors.white.withOpacity(0.10);
}

/// GlassBackground renders the deep midnight canvas with organic glowing blurred orbs
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GlassColors.backgroundDark,
      child: Stack(
        children: [
          // Top right glowing orb (Warm Orange / Pink)
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFFFF7A00),
                    Color(0xFFFF007A),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Top left smaller purple glow
          Positioned(
            top: 100,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7928CA).withOpacity(0.8),
                    const Color(0xFF4A00E0).withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Bottom right vibrant orb (Gold / Orange)
          Positioned(
            bottom: -50,
            right: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFFFFB800),
                    Color(0xFFFF5E3A),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Bottom left subtle magenta glow
          Positioned(
            bottom: 120,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF007A).withOpacity(0.5),
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

/// Frosted translucent glass card container with blur and subtle border
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
        color: backgroundColor ?? Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.18),
          width: 1.2,
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

/// Primary gradient button ("let's go!" style) from the reference layout
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
                colors: [Colors.grey.shade700, Colors.grey.shade800],
              )
            : (gradient ?? GlassColors.primaryGradient),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFFFF5E3A).withOpacity(0.35),
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
