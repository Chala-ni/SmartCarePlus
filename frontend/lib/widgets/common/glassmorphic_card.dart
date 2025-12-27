/// SMARTCARE+ Glassmorphic Card Widget
///
/// Frosted glass card effect with optional neon glow

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? glowColor;
  final double glowIntensity;
  final Color? backgroundColor;
  final Color? borderColor;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.glowColor,
    this.glowIntensity = 0.3,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glowColor!.withOpacity(glowIntensity),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.glassWhite,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? AppColors.glassBorder,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Animated glassmorphic card with pulse effect
class AnimatedGlassmorphicCard extends StatefulWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsets padding;
  final Color glowColor;
  final bool animate;

  const AnimatedGlassmorphicCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.glowColor = AppColors.neonCyan,
    this.animate = true,
  });

  @override
  State<AnimatedGlassmorphicCard> createState() => _AnimatedGlassmorphicCardState();
}

class _AnimatedGlassmorphicCardState extends State<AnimatedGlassmorphicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return GlassmorphicCard(
          blur: widget.blur,
          borderRadius: widget.borderRadius,
          padding: widget.padding,
          glowColor: widget.glowColor,
          glowIntensity: widget.animate ? _animation.value : 0.3,
          child: widget.child,
        );
      },
    );
  }
}
