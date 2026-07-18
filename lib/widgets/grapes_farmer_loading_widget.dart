import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

class GrapesFarmerLoadingWidget extends StatefulWidget {
  const GrapesFarmerLoadingWidget({super.key});

  @override
  State<GrapesFarmerLoadingWidget> createState() => _GrapesFarmerLoadingWidgetState();
}

class _GrapesFarmerLoadingWidgetState extends State<GrapesFarmerLoadingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SizedBox(
          width: 80,
          height: 100,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _GrapesLoadingPainter(_controller.value),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GrapesLoadingPainter extends CustomPainter {
  final double animationValue;
  _GrapesLoadingPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    
    // Draw Leaf/Stem at the top
    final Paint stemPaint = Paint()
      ..color = AppColors.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final Path stemPath = Path()
      ..moveTo(centerX, 20)
      ..quadraticBezierTo(centerX - 8, 8, centerX - 12, 12);
    canvas.drawPath(stemPath, stemPaint);

    final Paint leafPaint = Paint()
      ..color = AppColors.primaryGreen.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX + 6, 14), width: 12, height: 8),
      leafPaint,
    );

    // Grapes layout coordinates: 6 grapes in a triangle bunch
    // Top row: 3 grapes
    // Middle row: 2 grapes
    // Bottom row: 1 grape
    final List<Offset> grapeOffsets = [
      // Top Row (3)
      Offset(centerX - 16, 36),
      Offset(centerX, 34),
      Offset(centerX + 16, 36),
      // Middle Row (2)
      Offset(centerX - 8, 52),
      Offset(centerX + 8, 52),
      // Bottom Row (1)
      Offset(centerX, 68),
    ];

    // Grape paint color: Premium Grape Purple
    final Color grapeColor = const Color(0xFF6A1B9A);

    for (int i = 0; i < grapeOffsets.length; i++) {
      // Calculate a staggered delay for each grape pulse
      final double offset = (i / grapeOffsets.length) * 0.5;
      double t = (animationValue - offset) % 1.0;
      
      // Smooth sine pulse curve
      double pulse = 1.0 + 0.25 * (1.0 - (t - 0.5).abs() * 2.0);
      double opacity = 0.5 + 0.5 * (1.0 - (t - 0.5).abs() * 2.0);

      final Paint grapePaint = Paint()
        ..color = grapeColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        grapeOffsets[i],
        8.0 * pulse,
        grapePaint,
      );

      // Add a subtle glossy highlight on each grape
      final Paint highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * 0.4)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(grapeOffsets[i].dx - 3 * pulse, grapeOffsets[i].dy - 3 * pulse),
        2.5 * pulse,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrapesLoadingPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
