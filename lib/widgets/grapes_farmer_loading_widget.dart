import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

class GrapesFarmerLoadingWidget extends StatefulWidget {
  const GrapesFarmerLoadingWidget({super.key});

  @override
  State<GrapesFarmerLoadingWidget> createState() => _GrapesFarmerLoadingWidgetState();
}

class _GrapesFarmerLoadingWidgetState extends State<GrapesFarmerLoadingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _quoteIndex = 0;
  
  final List<String> _farmerQuotes = [
    "Patil, your vines are blooming... wealth is on the way! 🍇💰",
    "Analyzing soil and micro-climate for your bumper yield... 🌱📊",
    "Grapes are ripening, export quality profits are climbing! 🍇🚀",
    "Draksha AI is checking weather stations for your plot... 🌦️🎯",
    "Farming smart, earning big, and enjoying life! 🍇🏡😎"
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Rotate quotes every 3 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      setState(() {
        _quoteIndex = (_quoteIndex + 1) % _farmerQuotes.length;
      });
      return true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // Pulsing grapes and farmer icon
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.nature_people,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Animated quotes text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "DRAKSHA AI ANALYZING...",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 550),
                  child: Text(
                    _farmerQuotes[_quoteIndex],
                    key: ValueKey<int>(_quoteIndex),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
