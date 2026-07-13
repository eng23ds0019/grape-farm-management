import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 26,
    this.opacity = 0.68,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double opacity;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.42),
              width: 1.2,
            ),
            boxShadow: shadow
                ? [
                    BoxShadow(
                      color: AppColors.grapeGreen.withValues(alpha: 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
