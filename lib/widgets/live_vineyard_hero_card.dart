import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/colors.dart';
import '../services/weather_service.dart';

class LiveVineyardHeroCard extends StatefulWidget {
  final String plotName;
  final WeatherData? weatherData;
  final String smartStatus;
  final String aiInsight;
  final String lastUpdatedText;
  final bool isOffline;

  const LiveVineyardHeroCard({
    super.key,
    required this.plotName,
    required this.weatherData,
    required this.smartStatus,
    required this.aiInsight,
    required this.lastUpdatedText,
    this.isOffline = false,
  });

  @override
  State<LiveVineyardHeroCard> createState() => _LiveVineyardHeroCardState();
}

class _LiveVineyardHeroCardState extends State<LiveVineyardHeroCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  
  // Transition variables for smooth blending between weather states
  String _currentScene = "sunny";
  String _prevScene = "sunny";
  double _sceneTransition = 1.0;
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
    _updateSceneState();
  }

  @override
  void didUpdateWidget(covariant LiveVineyardHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSceneState();
  }

  void _updateSceneState() {
    if (widget.weatherData == null) return;
    
    final cond = widget.weatherData!.condition.toLowerCase();
    String newScene = "sunny";

    // Determine target scene based on weather details
    final now = DateTime.now();
    final isNightTime = now.hour < 6 || now.hour > 18;

    if (isNightTime) {
      newScene = "night";
    } else if (cond.contains("storm") || cond.contains("thunder")) {
      newScene = "storm";
    } else if (cond.contains("rain") || cond.contains("drizzle") || widget.weatherData!.rainfall > 0) {
      newScene = "rain";
    } else if (cond.contains("fog") || cond.contains("mist") || cond.contains("haze")) {
      newScene = "fog";
    } else if (cond.contains("cloud") || widget.weatherData!.humidity > 75) {
      newScene = "cloudy";
    }

    if (newScene != _currentScene) {
      setState(() {
        _prevScene = _currentScene;
        _currentScene = newScene;
        _sceneTransition = 0.0;
      });
      
      // Animate transition smoothly over 1.5 seconds
      Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 30));
        if (!mounted) return false;
        setState(() {
          _sceneTransition += 0.02;
        });
        if (_sceneTransition >= 1.0) {
          setState(() {
            _sceneTransition = 1.0;
            _prevScene = _currentScene;
          });
          return false; // stop loop
        }
        return true;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Calculate dynamic UV Index based on weather data and time of day
  int get _calculatedUvIndex {
    if (widget.weatherData == null) return 0;
    final now = DateTime.now();
    if (now.hour < 7 || now.hour > 17) return 0; // Dark
    
    int baseUv = 8; // Max mid-day clear
    if (now.hour < 9 || now.hour > 15) baseUv = 3;
    
    // Reduce based on condition/clouds
    final cond = widget.weatherData!.condition.toLowerCase();
    if (cond.contains("cloud")) baseUv = (baseUv * 0.5).round();
    if (cond.contains("rain") || cond.contains("storm")) baseUv = 1;
    return math.max(0, baseUv);
  }

  // Calculate Rain probability dynamically
  int get _calculatedRainProb {
    if (widget.weatherData == null) return 0;
    if (widget.weatherData!.rainfall > 0.0) return 100;
    
    final cond = widget.weatherData!.condition.toLowerCase();
    if (cond.contains("storm")) return 90;
    if (cond.contains("rain")) return 85;
    if (cond.contains("cloud")) return 45;
    if (widget.weatherData!.humidity > 80) return 60;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    final temp = widget.weatherData?.temperature ?? 27.0;
    final humidity = widget.weatherData?.humidity ?? 65;
    final wind = widget.weatherData?.windSpeed ?? 12.0;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Dynamic CustomPaint Vineyard Visual Hero Card
            Container(
              height: 240,
              width: double.infinity,
              color: Colors.grey[900],
              child: Stack(
                children: [
                  // Smooth Animated custom painter background
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _VineyardPainter(
                            animationValue: _animController.value,
                            currentScene: _currentScene,
                            prevScene: _prevScene,
                            transition: _sceneTransition,
                            windSpeed: wind,
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Top overlay details
                  Positioned(
                    top: 16,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Plot details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.plotName.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on, color: AppColors.softYellow.withValues(alpha: 0.9), size: 12),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.weatherData?.location ?? "Locating Vineyard...",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Weather badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getWeatherIcon(widget.weatherData?.condition ?? ""),
                                color: AppColors.softYellow,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.weatherData?.condition.toUpperCase() ?? "OFFLINE",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom weather metrics grid overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMetricItem(Icons.thermostat, "${temp.toStringAsFixed(1)}°C", "TEMP"),
                          _buildMetricItem(Icons.water_drop, "$humidity%", "HUMIDITY"),
                          _buildMetricItem(Icons.umbrella, "$_calculatedRainProb%", "RAIN %"),
                          _buildMetricItem(Icons.air, "${wind.toStringAsFixed(1)} km/h", "WIND"),
                          _buildMetricItem(Icons.cloud, "${widget.weatherData?.cloud_cover ?? 0}%", "CLOUD"),
                          _buildMetricItem(Icons.wb_sunny, "$_calculatedUvIndex", "UV"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Smart Advisor Box (Dynamic Insights Container)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(widget.smartStatus).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getStatusIcon(widget.smartStatus),
                              color: _getStatusColor(widget.smartStatus),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.smartStatus.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(widget.smartStatus),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        widget.isOffline ? "Cached Mode" : widget.lastUpdatedText,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.aiInsight,
                    style: const TextStyle(
                      color: AppColors.earthyBrown,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  IconData _getWeatherIcon(String cond) {
    cond = cond.toLowerCase();
    if (cond.contains("rain") || cond.contains("drizzle")) return Icons.thunderstorm;
    if (cond.contains("cloud")) return Icons.cloud;
    if (cond.contains("fog") || cond.contains("mist") || cond.contains("haze")) return Icons.blur_on;
    if (cond.contains("night")) return Icons.nightlight_round;
    return Icons.wb_sunny;
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status.contains("risk") || status.contains("danger") || status.contains("stress") || status.contains("high")) {
      return Colors.red[700]!;
    }
    if (status.contains("warn") || status.contains("rain expected") || status.contains("humidity")) {
      return Colors.amber[800]!;
    }
    return AppColors.primaryGreen;
  }

  IconData _getStatusIcon(String status) {
    status = status.toLowerCase();
    if (status.contains("risk") || status.contains("danger") || status.contains("stress") || status.contains("high")) {
      return Icons.warning_amber;
    }
    if (status.contains("warn") || status.contains("rain expected") || status.contains("humidity")) {
      return Icons.info_outline;
    }
    return Icons.check_circle_outline;
  }
}

class _VineyardPainter extends CustomPainter {
  final double animationValue;
  final String currentScene;
  final String prevScene;
  final double transition;
  final double windSpeed;

  _VineyardPainter({
    required this.animationValue,
    required this.currentScene,
    required this.prevScene,
    required this.transition,
    required this.windSpeed,
  });

  // Scene coloring config
  static const Map<String, List<Color>> skyColors = {
    "sunny": [Color(0xFF4FC3F7), Color(0xFFE1F5FE)],
    "cloudy": [Color(0xFF90A4AE), Color(0xFFECEFF1)],
    "rain": [Color(0xFF78909C), Color(0xFFCFD8DC)],
    "storm": [Color(0xFF37474F), Color(0xFF546E7A)],
    "fog": [Color(0xFFB0BEC5), Color(0xFFECEFF1)],
    "night": [Color(0xFF0D1B2A), Color(0xFF1B263B)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // ─── 1. SKY BACKGROUND BLENDING ───
    final List<Color> currSky = skyColors[currentScene] ?? skyColors["sunny"]!;
    final List<Color> prevSky = skyColors[prevScene] ?? skyColors["sunny"]!;
    
    final List<Color> blendedSky = [
      Color.lerp(prevSky[0], currSky[0], transition)!,
      Color.lerp(prevSky[1], currSky[1], transition)!,
    ];

    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: blendedSky,
    );
    canvas.drawRect(rect, Paint()..shader = skyGradient.createShader(rect));

    // ─── 2. SCENE SPECIAL EFFECTS (Stars, Sunrays, Clouds) ───
    final double opacityCurrent = transition;
    final double opacityPrev = 1.0 - transition;

    // Draw previous scene background effects
    _drawSceneEffects(canvas, size, prevScene, opacityPrev);
    // Draw current scene background effects
    _drawSceneEffects(canvas, size, currentScene, opacityCurrent);

    // ─── 3. HILLS / MOUNTAINS BACKGROUND ───
    final Paint hillPaint = Paint()
      ..color = Color.lerp(const Color(0xFF2E7D32), const Color(0xFF1B4332), isNight(currentScene) ? 0.8 : 0.2)!
      ..style = PaintingStyle.fill;

    final Path hillPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.65, size.width * 0.5, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.78, size.width, size.height * 0.68)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    // ─── 4. GRAPEVINE ROW DRAWING ───
    _drawGrapevineRows(canvas, size);

    // ─── 5. FOREGROUND WEATHER EFFECTS (Rain, Storm, Fog) ───
    _drawForegroundEffects(canvas, size, prevScene, opacityPrev);
    _drawForegroundEffects(canvas, size, currentScene, opacityCurrent);
  }

  bool isNight(String scene) => scene == "night";

  void _drawSceneEffects(Canvas canvas, Size size, String scene, double opacity) {
    if (opacity <= 0.02) return;

    if (scene == "night") {
      // Draw Stars
      final Paint starPaint = Paint()..color = Colors.white.withValues(alpha: opacity);
      final double twinkle = math.sin(animationValue * math.pi * 6.0) * 0.5 + 0.5;
      
      final List<Offset> stars = [
        const Offset(30, 40), const Offset(90, 25), const Offset(150, 45),
        const Offset(220, 30), const Offset(280, 50), const Offset(70, 70),
        const Offset(180, 75), const Offset(250, 90), const Offset(320, 35)
      ];

      for (int i = 0; i < stars.length; i++) {
        final double starScale = (i % 2 == 0) ? twinkle : (1.0 - twinkle);
        canvas.drawCircle(stars[i], 1.5 * starScale, starPaint);
      }
      
      // Draw Moon
      final Paint moonPaint = Paint()..color = const Color(0xFFFFF3E0).withValues(alpha: opacity);
      canvas.drawCircle(Offset(size.width - 50, 45), 18, moonPaint);
      // Moon glow
      canvas.drawCircle(Offset(size.width - 50, 45), 24, Paint()..color = Colors.white.withValues(alpha: opacity * 0.08));
    } 
    
    else if (scene == "sunny") {
      // Draw Sunbeams
      final double sunCenterX = size.width - 40;
      const double sunCenterY = 40.0;
      final Paint sunPaint = Paint()..color = Colors.yellow[600]!.withValues(alpha: opacity);
      canvas.drawCircle(const Offset(sunCenterX, sunCenterY), 16, sunPaint);

      final double pulse = math.sin(animationValue * math.pi * 4.0) * 0.08 + 1.0;
      final Paint sunGlowPaint = Paint()..color = Colors.yellow[300]!.withValues(alpha: opacity * 0.15);
      canvas.drawCircle(const Offset(sunCenterX, sunCenterY), 28 * pulse, sunGlowPaint);

      // Birds flying occasionally
      final Paint birdPaint = Paint()
        ..color = Colors.black45.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final double birdX = (animationValue * (size.width + 100)) - 50;
      final List<Offset> birdOffsets = [
        Offset(birdX, 45),
        Offset(birdX - 25, 38),
        Offset(birdX - 12, 52),
      ];

      for (var offset in birdOffsets) {
        if (offset.dx > 0 && offset.dx < size.width) {
          final Path bird = Path()
            ..moveTo(offset.dx - 6, offset.dy + 3)
            ..quadraticBezierTo(offset.dx - 3, offset.dy - 3, offset.dx, offset.dy)
            ..quadraticBezierTo(offset.dx + 3, offset.dy - 3, offset.dx + 6, offset.dy + 3);
          canvas.drawPath(bird, birdPaint);
        }
      }
    } 
    
    else if (scene == "cloudy" || scene == "rain" || scene == "storm") {
      // Drifting clouds
      final Paint cloudPaint = Paint()
        ..color = (scene == "storm" ? Colors.blueGrey[800]! : Colors.blueGrey[100]!).withValues(alpha: opacity * 0.85);

      final double cloudOffset = animationValue * size.width;
      final List<Offset> clouds = [
        Offset(cloudOffset % (size.width + 80) - 40, 20),
        Offset((cloudOffset + size.width * 0.5) % (size.width + 120) - 60, 35),
      ];

      for (var offset in clouds) {
        canvas.drawCircle(offset, 25, cloudPaint);
        canvas.drawCircle(Offset(offset.dx - 16, offset.dy + 6), 18, cloudPaint);
        canvas.drawCircle(Offset(offset.dx + 16, offset.dy + 6), 18, cloudPaint);
      }
    }
  }

  void _drawGrapevineRows(Canvas canvas, Size size) {
    // Determine wind sway
    final double windFactor = math.max(6.0, windSpeed) / 15.0; // scaled wind sway
    final double sway = math.sin(animationValue * math.pi * 8.0) * 3.0 * windFactor;
    
    final Paint postPaint = Paint()
      ..color = const Color(0xFF4A3B32) // rustic wood
      ..strokeWidth = 4.0;
      
    final Paint wirePaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1.0;

    // Draw trellis posts
    final List<double> postXPositions = [size.width * 0.15, size.width * 0.5, size.width * 0.85];
    final double wireY1 = size.height * 0.72;
    final double wireY2 = size.height * 0.84;

    // Connect wires
    canvas.drawLine(Offset(0, wireY1), Offset(size.width, wireY1), wirePaint);
    canvas.drawLine(Offset(0, wireY2), Offset(size.width, wireY2), wirePaint);

    for (var x in postXPositions) {
      canvas.drawLine(Offset(x, size.height * 0.65), Offset(x, size.height * 0.95), postPaint);
    }

    // Draw Vine Leaves and Grape Bunches hanging on wires
    final Paint leafPaint = Paint()
      ..color = const Color(0xFF388E3C)
      ..style = PaintingStyle.fill;

    final Paint grapePaint = Paint()
      ..color = const Color(0xFF4A148C) // rich grape purple
      ..style = PaintingStyle.fill;

    final List<double> vineCenters = [
      size.width * 0.32,
      size.width * 0.68,
    ];

    for (var centerX in vineCenters) {
      // Main wood trunk
      final Path trunk = Path()
        ..moveTo(centerX, size.height * 0.95)
        ..quadraticBezierTo(centerX - 10, size.height * 0.82, centerX, wireY1);
      canvas.drawPath(trunk, Paint()..color = const Color(0xFF5D4037)..strokeWidth = 5.0..style = PaintingStyle.stroke);

      // Swaying canopy leaves
      for (int i = -3; i <= 3; i++) {
        final double leafX = centerX + (i * 20) + sway;
        // Upper leaf canopy
        canvas.drawCircle(Offset(leafX, wireY1 - 4), 10, leafPaint);
        // Lower leaf canopy
        canvas.drawCircle(Offset(leafX - 6, wireY2), 9, leafPaint);

        // Hanging grape bunches (drawn staggered under leaves)
        if (i.abs() == 1) {
          final double grapeX = leafX;
          final double grapeY = wireY1 + 10;
          
          // Bunch structure (triangle of dots)
          canvas.drawCircle(Offset(grapeX - 4, grapeY), 3.5, grapePaint);
          canvas.drawCircle(Offset(grapeX, grapeY), 3.5, grapePaint);
          canvas.drawCircle(Offset(grapeX + 4, grapeY), 3.5, grapePaint);
          canvas.drawCircle(Offset(grapeX - 2, grapeY + 5), 3.5, grapePaint);
          canvas.drawCircle(Offset(grapeX + 2, grapeY + 5), 3.5, grapePaint);
          canvas.drawCircle(Offset(grapeX, grapeY + 9), 3.5, grapePaint);
        }
      }
    }
  }

  void _drawForegroundEffects(Canvas canvas, Size size, String scene, double opacity) {
    if (opacity <= 0.02) return;

    if (scene == "rain" || scene == "storm") {
      final int dropsCount = scene == "storm" ? 45 : 20;
      final Paint rainPaint = Paint()
        ..color = Colors.white70.withValues(alpha: opacity * 0.6)
        ..strokeWidth = scene == "storm" ? 1.5 : 1.0;

      final double angleSlant = (windSpeed / 20.0) * 12.0;

      for (int i = 0; i < dropsCount; i++) {
        final double spawnX = (i * (size.width / dropsCount) + (animationValue * 150)) % size.width;
        final double spawnY = (animationValue * size.height + (i * 25)) % size.height;

        canvas.drawLine(
          Offset(spawnX, spawnY),
          Offset(spawnX - angleSlant, spawnY + 12),
          rainPaint,
        );
      }

      // Lightning triggers on storm scene periodically
      if (scene == "storm") {
        final double strikeTrigger = math.sin(animationValue * math.pi * 10.0);
        if (strikeTrigger > 0.94) {
          // Screen flash overlay
          canvas.drawRect(
            Offset.zero & size,
            Paint()..color = Colors.white.withValues(alpha: opacity * 0.28),
          );

          // Lightning Bolt path
          final Paint boltPaint = Paint()
            ..color = Colors.cyan[100]!.withValues(alpha: opacity)
            ..strokeWidth = 3.5
            ..style = PaintingStyle.stroke;

          final double strikeX = size.width * 0.4;
          final Path bolt = Path()
            ..moveTo(strikeX, 0)
            ..lineTo(strikeX - 20, size.height * 0.3)
            ..lineTo(strikeX + 10, size.height * 0.25)
            ..lineTo(strikeX - 10, size.height * 0.6)
            ..lineTo(strikeX, size.height * 0.55)
            ..lineTo(strikeX - 15, size.height * 0.75);
          canvas.drawPath(bolt, boltPaint);
        }
      }
    } 
    
    else if (scene == "fog") {
      // Layered fog sheets drifting horizontally
      final Paint fogPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * 0.28)
        ..style = PaintingStyle.fill;

      final double drift = animationValue * size.width;
      
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(drift % (size.width + 200) - 100, size.height * 0.8),
          width: size.width * 1.2,
          height: 35,
        ),
        fogPaint,
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset((drift + size.width * 0.5) % (size.width + 200) - 100, size.height * 0.6),
          width: size.width * 1.5,
          height: 25,
        ),
        fogPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VineyardPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.currentScene != currentScene ||
        oldDelegate.prevScene != prevScene ||
        oldDelegate.transition != transition ||
        oldDelegate.windSpeed != windSpeed;
  }
}
