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
  final String langCode;

  const LiveVineyardHeroCard({
    super.key,
    required this.plotName,
    required this.weatherData,
    required this.smartStatus,
    required this.aiInsight,
    required this.lastUpdatedText,
    required this.langCode,
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

  // Localized Translation Table for Vineyard Hero Card
  static const Map<String, Map<String, String>> _localizations = {
    'en-IN': {
      'TEMP': 'TEMP',
      'HUMIDITY': 'HUMID',
      'RAIN': 'RAIN',
      'WIND': 'WIND',
      'CLOUD': 'CLOUD',
      'UV': 'UV',
      'PRES': 'PRES',
      'VIS': 'VIS',
      'RISE': 'RISE',
      'SET': 'SET',
      'HIGH': 'HIGH',
      'LOW': 'LOW',
      'WEATHER': 'WEATHER',
      'OFFLINE': 'OFFLINE',
      'Excellent Growing Conditions': 'Excellent Growing Conditions',
      'Analyzing vine canopy data & weather models...': 'Analyzing vine canopy data & weather models...',
      'Weather is currently stable. Continue regular monitoring.': 'Weather is currently stable. Continue regular monitoring.',
      'Showing last available weather': 'Showing last available weather',
    },
    'kn-IN': {
      'TEMP': 'ತಾಪಮಾನ',
      'HUMIDITY': 'ಆರ್ದ್ರತೆ',
      'RAIN': 'ಮಳೆ %',
      'WIND': 'ಗಾಳಿ',
      'CLOUD': 'ಮೋಡ',
      'UV': 'ಯುವಿ',
      'PRES': 'ಒತ್ತಡ',
      'VIS': 'ಗೋಚರತೆ',
      'RISE': 'ಸೂರ್ಯೋದಯ',
      'SET': 'ಸೂರ್ಯಾಸ್ತ',
      'HIGH': 'ಗರಿಷ್ಠ',
      'LOW': 'ಕನಿಷ್ಠ',
      'WEATHER': 'ಹವಾಮಾನ',
      'OFFLINE': 'ಆಫ್‌ಲೈನ್',
      'Excellent Growing Conditions': 'ಅತ್ಯುತ್ತಮ ಬೆಳವಣಿಗೆಯ ವಾತಾವರಣ',
      'Analyzing vine canopy data & weather models...': 'ದ್ರಾಕ್ಷಿ ತೋಟದ ಹವಾಮಾನವನ್ನು ವಿಶ್ಲೇಷಿಸಲಾಗುತ್ತಿದೆ...',
      'Weather is currently stable. Continue regular monitoring.': 'ಹವಾಮಾನ ಸದ್ಯಕ್ಕೆ ಸ್ಥಿರವಾಗಿದೆ. ನಿಯಮಿತ ಮೇಲ್ವಿಚಾರಣೆ ಮುಂದುವರಿಸಿ.',
      'Showing last available weather': 'ಹಳೆಯ ಹವಾಮಾನವನ್ನು ತೋರಿಸಲಾಗುತ್ತಿದೆ',
    },
    'hi-IN': {
      'TEMP': 'तापमान',
      'HUMIDITY': 'आर्द्रता',
      'RAIN': 'बारिश %',
      'WIND': 'हवा',
      'CLOUD': 'बादल',
      'UV': 'यूवी',
      'PRES': 'दबाव',
      'VIS': 'दृश्यता',
      'RISE': 'सूर्योदय',
      'SET': 'सूर्यास्त',
      'HIGH': 'अधिकतम',
      'LOW': 'न्यूनतम',
      'WEATHER': 'मौसम',
      'OFFLINE': 'ऑफलाइन',
      'Excellent Growing Conditions': 'उत्कृष्ट विकास की स्थिति',
      'Analyzing vine canopy data & weather models...': 'अंगूर के बाग के मौसम का विश्लेषण किया जा रहा है...',
      'Weather is currently stable. Continue regular monitoring.': 'मौसम वर्तमान में स्थिर है। नियमित निगरानी जारी रखें।',
      'Showing last available weather': 'पुराना मौसम दिखाया जा रहा है',
    }
  };

  String _t(String key) {
    final code = widget.langCode == 'kn-IN' ? 'kn-IN' : (widget.langCode == 'hi-IN' ? 'hi-IN' : 'en-IN');
    return _localizations[code]?[key] ?? key;
  }

  String _formatTime(int unixTimestamp) {
    if (unixTimestamp == 0) return "--:--";
    final dt = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    return "$hour:$min $ampm";
  }

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

    // Determine target scene based on weather details & time of day
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
          return false;
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

  int get _calculatedUvIndex {
    if (widget.weatherData == null) return 0;
    final now = DateTime.now();
    if (now.hour < 7 || now.hour > 17) return 0; 
    
    int baseUv = 8;
    if (now.hour < 9 || now.hour > 15) baseUv = 3;
    
    final cond = widget.weatherData!.condition.toLowerCase();
    if (cond.contains("cloud")) baseUv = (baseUv * 0.5).round();
    if (cond.contains("rain") || cond.contains("storm")) baseUv = 1;
    return math.max(0, baseUv);
  }

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
    final pressure = widget.weatherData?.pressure ?? 1013;
    final visibility = (widget.weatherData?.visibility ?? 10000) / 1000.0;
    final sunriseText = _formatTime(widget.weatherData?.sunrise ?? 0);
    final sunsetText = _formatTime(widget.weatherData?.sunset ?? 0);
    final tempMax = widget.weatherData?.temp_max ?? temp;
    final tempMin = widget.weatherData?.temp_min ?? temp;
    
    // Fallback localization for status message
    String displayStatus = widget.smartStatus;
    if (displayStatus == "Excellent Growing Conditions" || displayStatus == "Loading status...") {
      displayStatus = _t(displayStatus);
    }
    String displayInsight = widget.aiInsight;
    if (displayInsight == "Analyzing vine canopy data & weather models..." ||
        displayInsight == "Weather is currently stable. Continue regular monitoring.") {
      displayInsight = _t(displayInsight);
    }
    
    String updatedLabel = widget.lastUpdatedText;
    if (updatedLabel.contains("Showing last available weather")) {
      updatedLabel = _t("Showing last available weather") + (updatedLabel.contains("(") ? " (${updatedLabel.split('(')[1]}" : "");
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Dynamic CustomPaint Photorealistic Vineyard Visual Hero Card
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.grey[950],
              child: Stack(
                children: [
                  // Smooth Animated custom painter background
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _PhotorealisticVineyardPainter(
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
                                  shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on, color: AppColors.softYellow.withValues(alpha: 0.95), size: 12),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.weatherData?.location ?? "Locating Vineyard...",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
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
                            color: Colors.black.withValues(alpha: 0.45),
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
                                widget.weatherData != null 
                                    ? widget.weatherData!.condition.toUpperCase() 
                                    : _t("OFFLINE"),
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
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Primary row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetricItem(Icons.thermostat, "${temp.toStringAsFixed(1)}°C", _t("TEMP")),
                              _buildMetricItem(Icons.water_drop, "$humidity%", _t("HUMIDITY")),
                              _buildMetricItem(Icons.umbrella, "$_calculatedRainProb%", _t("RAIN")),
                              _buildMetricItem(Icons.air, "${wind.toStringAsFixed(1)} km/h", _t("WIND")),
                              _buildMetricItem(Icons.cloud, "${widget.weatherData?.cloud_cover ?? 0}%", _t("CLOUD")),
                              _buildMetricItem(Icons.wb_sunny, "$_calculatedUvIndex", _t("UV")),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Secondary Weather Intelligence row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetricItem(Icons.speed, "$pressure hPa", _t("PRES")),
                              _buildMetricItem(Icons.visibility, "${visibility.toStringAsFixed(1)} km", _t("VIS")),
                              _buildMetricItem(Icons.vertical_align_top, "${tempMax.toStringAsFixed(1)}°", _t("HIGH")),
                              _buildMetricItem(Icons.vertical_align_bottom, "${tempMin.toStringAsFixed(1)}°", _t("LOW")),
                              _buildMetricItem(Icons.wb_twilight, sunriseText, _t("RISE")),
                              _buildMetricItem(Icons.nights_stay, sunsetText, _t("SET")),
                            ],
                          ),
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
                      Expanded(
                        child: Row(
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
                            Expanded(
                              child: Text(
                                displayStatus.toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _getStatusColor(widget.smartStatus),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isOffline ? _t("OFFLINE") : updatedLabel,
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
                    displayInsight,
                    style: const TextStyle(
                      color: AppColors.earthyBrown,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
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
    return SizedBox(
      width: 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(height: 1),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
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

class _PhotorealisticVineyardPainter extends CustomPainter {
  final double animationValue;
  final String currentScene;
  final String prevScene;
  final double transition;
  final double windSpeed;

  _PhotorealisticVineyardPainter({
    required this.animationValue,
    required this.currentScene,
    required this.prevScene,
    required this.transition,
    required this.windSpeed,
  });

  static const Map<String, List<Color>> skyColors = {
    "sunny": [Color(0xFF00B0FF), Color(0xFFE0F7FA)],
    "cloudy": [Color(0xFF607D8B), Color(0xFFCFD8DC)],
    "rain": [Color(0xFF455A64), Color(0xFF90A4AE)],
    "storm": [Color(0xFF263238), Color(0xFF37474F)],
    "fog": [Color(0xFF78909C), Color(0xFFECEFF1)],
    "night": [Color(0xFF000428), Color(0xFF004E92)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // ─── 1. SKY GRADIENT BLENDING ───
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

    // ─── 2. DETAILED BACKGROUND SCENE EFFECTS ───
    final double opacityCurrent = transition;
    final double opacityPrev = 1.0 - transition;

    _drawSceneEffects(canvas, size, prevScene, opacityPrev);
    _drawSceneEffects(canvas, size, currentScene, opacityCurrent);

    // ─── 3. MULTI-LAYERED SILHOUETTE HILLS ───
    final double hillDarkness = currentScene == "night" ? 0.9 : (currentScene == "storm" ? 0.7 : 0.2);
    
    // Distant Hills (Lighter, Blueish-Green)
    final Paint distHillPaint = Paint()
      ..color = Color.lerp(const Color(0xFF388E3C).withValues(alpha: 0.7), Colors.black, hillDarkness)!
      ..style = PaintingStyle.fill;
    final Path distHill = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.6, size.width * 0.6, size.height * 0.68)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.72, size.width, size.height * 0.63)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(distHill, distHillPaint);

    // Near Hills (Darker, Textured)
    final Paint nearHillPaint = Paint()
      ..color = Color.lerp(const Color(0xFF1B5E20), Colors.black, hillDarkness)!
      ..style = PaintingStyle.fill;
    final Path nearHill = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.68, size.width * 0.5, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width, size.height * 0.7)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(nearHill, nearHillPaint);

    // ─── 4. GRAPEVINE ROWS TRELLIS & TRUNK ───
    _drawGrapevineRows(canvas, size);

    // ─── 5. FOREGROUND WEATHER LAYERS (Rain, Lightning, Fog) ───
    _drawForegroundEffects(canvas, size, prevScene, opacityPrev);
    _drawForegroundEffects(canvas, size, currentScene, opacityCurrent);
  }

  void _drawSceneEffects(Canvas canvas, Size size, String scene, double opacity) {
    if (opacity <= 0.02) return;

    if (scene == "night") {
      // Starry sky twinkle
      final Paint starPaint = Paint()..color = Colors.white.withValues(alpha: opacity);
      final double twinkle = math.sin(animationValue * math.pi * 6.0) * 0.5 + 0.5;
      
      final List<Offset> stars = [
        const Offset(25, 30), const Offset(80, 20), const Offset(140, 35),
        const Offset(210, 25), const Offset(270, 45), const Offset(60, 60),
        const Offset(170, 65), const Offset(240, 80), const Offset(310, 30),
        const Offset(110, 70), const Offset(50, 90), const Offset(290, 75)
      ];

      for (int i = 0; i < stars.length; i++) {
        final double starScale = (i % 3 == 0) ? twinkle : ((i % 3 == 1) ? (1.0 - twinkle) : 0.7);
        canvas.drawCircle(stars[i], 1.4 * starScale, starPaint);
      }
      
      // Photorealistic moon with craters
      final double moonX = size.width - 50;
      final double moonY = 45.0;
      final Paint moonPaint = Paint()..color = const Color(0xFFFFFDE7).withValues(alpha: opacity);
      canvas.drawCircle(Offset(moonX, moonY), 16, moonPaint);
      // Moon glow
      canvas.drawCircle(Offset(moonX, moonY), 24, Paint()..color = Colors.white.withValues(alpha: opacity * 0.06));
      
      // Crater details
      final Paint craterPaint = Paint()..color = const Color(0xFFE0DBB5).withValues(alpha: opacity * 0.5);
      canvas.drawCircle(Offset(moonX - 5, moonY - 4), 3, craterPaint);
      canvas.drawCircle(Offset(moonX + 4, moonY + 6), 2, craterPaint);
      canvas.drawCircle(Offset(moonX - 2, moonY + 8), 2.5, craterPaint);
    } 
    
    else if (scene == "sunny") {
      final double sunX = size.width - 50;
      final double sunY = 45.0;
      
      // Radial Sunlight flare
      final Paint sunGlow = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.yellow[300]!.withValues(alpha: opacity * 0.3),
            Colors.yellow[500]!.withValues(alpha: opacity * 0.08),
            Colors.transparent
          ],
        ).createShader(Rect.fromCircle(center: Offset(sunX, sunY), radius: 60));
      canvas.drawCircle(Offset(sunX, sunY), 60, sunGlow);

      final Paint sunCore = Paint()..color = Colors.yellow[100]!.withValues(alpha: opacity);
      canvas.drawCircle(Offset(sunX, sunY), 14, sunCore);

      // Birds flying realistically (staggered V shapes)
      final Paint birdPaint = Paint()
        ..color = Colors.blueGrey[900]!.withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;

      final double birdX = (animationValue * (size.width + 120)) - 60;
      final List<Offset> birdOffsets = [
        Offset(birdX, 35),
        Offset(birdX - 22, 28),
        Offset(birdX - 14, 44),
      ];

      for (var offset in birdOffsets) {
        if (offset.dx > 0 && offset.dx < size.width) {
          final Path bird = Path()
            ..moveTo(offset.dx - 6, offset.dy + 2)
            ..quadraticBezierTo(offset.dx - 3, offset.dy - 3, offset.dx, offset.dy)
            ..quadraticBezierTo(offset.dx + 3, offset.dy - 3, offset.dx + 6, offset.dy + 2);
          canvas.drawPath(bird, birdPaint);
        }
      }
    } 
    
    else if (scene == "cloudy" || scene == "rain" || scene == "storm") {
      // Photorealistic dark cumulus clouds
      final Paint cloudPaint = Paint()
        ..color = (scene == "storm" ? Colors.blueGrey[800]! : Colors.blueGrey[200]!).withValues(alpha: opacity * 0.7);

      final double cloudOffset = animationValue * size.width * 0.6;
      final List<Offset> clouds = [
        Offset(cloudOffset % (size.width + 120) - 60, 20),
        Offset((cloudOffset + size.width * 0.4) % (size.width + 140) - 70, 32),
      ];

      for (var offset in clouds) {
        canvas.drawOval(Rect.fromCenter(center: offset, width: 80, height: 32), cloudPaint);
        canvas.drawOval(Rect.fromCenter(center: Offset(offset.dx - 20, offset.dy + 4), width: 50, height: 26), cloudPaint);
        canvas.drawOval(Rect.fromCenter(center: Offset(offset.dx + 20, offset.dy + 4), width: 50, height: 26), cloudPaint);
      }
    }
  }

  void _drawGrapevineRows(Canvas canvas, Size size) {
    final double windFactor = math.max(6.0, windSpeed) / 16.0;
    final double sway = math.sin(animationValue * math.pi * 8.0) * 3.2 * windFactor;
    
    // Trellis wood texture
    final Paint postPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.square;
    
    final Paint wirePaint = Paint()
      ..color = Colors.blueGrey[300]!
      ..strokeWidth = 1.1;

    final double wireY1 = size.height * 0.73;
    final double wireY2 = size.height * 0.85;

    // Trellis wires
    canvas.drawLine(Offset(0, wireY1), Offset(size.width, wireY1), wirePaint);
    canvas.drawLine(Offset(0, wireY2), Offset(size.width, wireY2), wirePaint);

    final List<double> postXs = [size.width * 0.12, size.width * 0.5, size.width * 0.88];
    for (var x in postXs) {
      canvas.drawLine(Offset(x, size.height * 0.66), Offset(x, size.height * 0.96), postPaint);
      // Detailed grain line
      canvas.drawLine(
        Offset(x + 1, size.height * 0.68),
        Offset(x + 1, size.height * 0.94),
        Paint()..color = Colors.black38..strokeWidth = 1.0,
      );
    }

    // Leaf Shaders
    final isNightScene = currentScene == "night";
    final Paint leafPaint = Paint()
      ..shader = RadialGradient(
        colors: isNightScene
            ? [const Color(0xFF1B4332), const Color(0xFF081C15)]
            : [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Realistic Grape cluster colors
    final Paint grapePaint = Paint()
      ..shader = RadialGradient(
        colors: isNightScene
            ? [const Color(0xFF4A148C), const Color(0xFF1A0033)]
            : [const Color(0xFF8E24AA), const Color(0xFF311B92)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final List<double> vineCenters = [size.width * 0.31, size.width * 0.69];

    for (var centerX in vineCenters) {
      // Wood trunk paths
      final Path trunk = Path()
        ..moveTo(centerX, size.height * 0.96)
        ..quadraticBezierTo(centerX - 12, size.height * 0.83, centerX, wireY1);
      canvas.drawPath(trunk, Paint()..color = const Color(0xFF4E342E)..strokeWidth = 5.5..style = PaintingStyle.stroke);

      // Realistic detailed grape leaves & bunches
      for (int i = -3; i <= 3; i++) {
        final double leafX = centerX + (i * 22) + sway;
        
        // Draw realistic 3-lobed grape leaf shapes using bezier paths
        _drawGrapeLeaf(canvas, Offset(leafX, wireY1 - 5), 11, leafPaint);
        _drawGrapeLeaf(canvas, Offset(leafX - 5, wireY2), 10, leafPaint);

        // Glistening Grape Bunches
        if (i.abs() == 1) {
          final double grapeX = leafX;
          final double grapeY = wireY1 + 10;
          
          // Specular grape cluster drawing
          _drawSpecularGrape(canvas, Offset(grapeX - 5, grapeY), 4, grapePaint);
          _drawSpecularGrape(canvas, Offset(grapeX + 1, grapeY), 4.2, grapePaint);
          _drawSpecularGrape(canvas, Offset(grapeX + 6, grapeY), 3.8, grapePaint);
          _drawSpecularGrape(canvas, Offset(grapeX - 2, grapeY + 6), 4, grapePaint);
          _drawSpecularGrape(canvas, Offset(grapeX + 3, grapeY + 6), 4.2, grapePaint);
          _drawSpecularGrape(canvas, Offset(grapeX + 1, grapeY + 11), 3.8, grapePaint);
        }
      }
    }
  }

  void _drawGrapeLeaf(Canvas canvas, Offset center, double radius, Paint leafPaint) {
    final Path leaf = Path();
    final double x = center.dx;
    final double y = center.dy;
    
    // Draw highly structured lobed grape leaf outline
    leaf.moveTo(x, y - radius);
    // Top lobe
    leaf.quadraticBezierTo(x - radius * 0.8, y - radius * 0.8, x - radius, y - radius * 0.2);
    // Side lobes
    leaf.quadraticBezierTo(x - radius * 1.3, y + radius * 0.3, x - radius * 0.5, y + radius * 0.8);
    // Base/Tip
    leaf.quadraticBezierTo(x, y + radius * 1.3, x + radius * 0.5, y + radius * 0.8);
    leaf.quadraticBezierTo(x + radius * 1.3, y + radius * 0.3, x + radius, y - radius * 0.2);
    leaf.quadraticBezierTo(x + radius * 0.8, y - radius * 0.8, x, y - radius);
    leaf.close();

    canvas.drawPath(leaf, leafPaint);

    // Drawing leaf veins for photorealism
    final Paint veinPaint = Paint()
      ..color = const Color(0xFF81C784).withValues(alpha: 0.5)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(x, y + radius * 0.8), Offset(x, y - radius * 0.6), veinPaint);
    canvas.drawLine(Offset(x, y + radius * 0.3), Offset(x - radius * 0.7, y - radius * 0.2), veinPaint);
    canvas.drawLine(Offset(x, y + radius * 0.3), Offset(x + radius * 0.7, y - radius * 0.2), veinPaint);
  }

  void _drawSpecularGrape(Canvas canvas, Offset center, double radius, Paint grapePaint) {
    // Draw grape body
    canvas.drawCircle(center, radius, grapePaint);
    
    // Specular highlight dot (glistening light reflection)
    final Paint highlight = Paint()..color = Colors.white.withValues(alpha: 0.65);
    canvas.drawCircle(Offset(center.dx - radius * 0.35, center.dy - radius * 0.35), radius * 0.25, highlight);
  }

  void _drawForegroundEffects(Canvas canvas, Size size, String scene, double opacity) {
    if (opacity <= 0.02) return;

    if (scene == "rain" || scene == "storm") {
      final int count = scene == "storm" ? 50 : 25;
      final Paint rainPaint = Paint()
        ..color = Colors.white70.withValues(alpha: opacity * 0.45)
        ..strokeWidth = scene == "storm" ? 1.6 : 1.1;

      final double angleSlant = (windSpeed / 18.0) * 14.0;

      for (int i = 0; i < count; i++) {
        final double spawnX = (i * (size.width / count) + (animationValue * 200)) % size.width;
        final double spawnY = (animationValue * size.height + (i * 20)) % size.height;

        canvas.drawLine(
          Offset(spawnX, spawnY),
          Offset(spawnX - angleSlant, spawnY + 14),
          rainPaint,
        );
      }

      // Volumetric lightning bolts (Storm scene)
      if (scene == "storm") {
        final double strikeTrigger = math.sin(animationValue * math.pi * 10.0);
        if (strikeTrigger > 0.95) {
          // Ambient sky flash
          canvas.drawRect(
            Offset.zero & size,
            Paint()..color = Colors.white.withValues(alpha: opacity * 0.25),
          );

          // Realistic zig-zag branching walk path
          final Paint boltPaint = Paint()
            ..color = const Color(0xFFE0F7FA).withValues(alpha: opacity)
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

          final double strikeX = size.width * 0.45;
          final Path bolt = Path()
            ..moveTo(strikeX, 0)
            ..lineTo(strikeX - 15, size.height * 0.25)
            ..lineTo(strikeX + 8, size.height * 0.22)
            ..lineTo(strikeX - 8, size.height * 0.5)
            ..lineTo(strikeX + 4, size.height * 0.45)
            ..lineTo(strikeX - 12, size.height * 0.7);
          canvas.drawPath(bolt, boltPaint);
        }
      }
    } 
    
    else if (scene == "fog") {
      // Realistic volumetric mist layers moving independently
      final Paint fogPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * 0.3)
        ..style = PaintingStyle.fill;

      final double drift = animationValue * size.width * 0.8;
      
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(drift % (size.width + 240) - 120, size.height * 0.82),
          width: size.width * 1.3,
          height: 38,
        ),
        fogPaint,
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset((drift + size.width * 0.6) % (size.width + 240) - 120, size.height * 0.62),
          width: size.width * 1.5,
          height: 28,
        ),
        fogPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PhotorealisticVineyardPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.currentScene != currentScene ||
        oldDelegate.prevScene != prevScene ||
        oldDelegate.transition != transition ||
        oldDelegate.windSpeed != windSpeed;
  }
}
