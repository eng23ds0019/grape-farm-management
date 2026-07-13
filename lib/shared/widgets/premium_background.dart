import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class PremiumBackground extends StatelessWidget {
  const PremiumBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9FFF0), Color(0xFFF8FFF2), Color(0xFFE1F7D5)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: _VineCircle(
              size: 240,
              color: AppColors.grapeGreen.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: 64,
            left: -40,
            child: _VineCircle(
              size: 160,
              color: AppColors.softYellow.withValues(alpha: 0.34),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -50,
            child: _VineCircle(
              size: 220,
              color: AppColors.freshGreen.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -70,
            child: _VineCircle(
              size: 180,
              color: AppColors.grapePurple.withValues(alpha: 0.08),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _VineCircle extends StatelessWidget {
  const _VineCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
