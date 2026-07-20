import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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
    key,
    required this.plotName,
    required this.weatherData,
    required this.smartStatus,
    required this.aiInsight,
    required this.lastUpdatedText,
    required this.langCode,
    this.isOffline = false,
  }) : super(key: key);

  @override
  State<LiveVineyardHeroCard> createState() => _LiveVineyardHeroCardState();
}

class _LiveVineyardHeroCardState extends State<LiveVineyardHeroCard> {
  // Video Player Controllers
  VideoPlayerController? _sunnyController;
  VideoPlayerController? _cloudyController;
  VideoPlayerController? _rainController;
  VideoPlayerController? _nightController;

  bool _initialized = false;
  String _activeVideo = "sunny";

  // Localized Translation Table for labels
  static const Map<String, Map<String, String>> _localizations = {
    'en-IN': {
      'TEMP': 'TEMP',
      'HUMIDITY': 'HUMID',
      'RAIN': 'RAIN',
      'WIND': 'WIND',
      'CLOUD': 'CLOUD',
      'UV': 'UV',
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

  @override
  void initState() {
    super.initState();
    _preloadVideoControllers();
  }

  Future<void> _preloadVideoControllers() async {
    _sunnyController = VideoPlayerController.asset("assets/vedios/vineyard_sunny.mp4");
    _cloudyController = VideoPlayerController.asset("assets/vedios/vineyard_cloudy.mp4");
    _rainController = VideoPlayerController.asset("assets/vedios/vineyard_rain.mp4");
    _nightController = VideoPlayerController.asset("assets/vedios/vineyard_night.mp4");

    try {
      await Future.wait([
        _sunnyController!.initialize(),
        _cloudyController!.initialize(),
        _rainController!.initialize(),
        _nightController!.initialize(),
      ]);

      if (!mounted) return;

      setState(() {
        _initialized = true;
      });

      // Loop all and mute them
      for (var controller in [_sunnyController, _cloudyController, _rainController, _nightController]) {
        if (controller != null) {
          await controller.setLooping(true);
          await controller.setVolume(0.0);
        }
      }

      _syncVideoWithWeather();
    } catch (e) {
      debugPrint("LiveVineyardHeroCard: Video initialization error: $e");
    }
  }

  @override
  void didUpdateWidget(covariant LiveVineyardHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initialized) {
      _syncVideoWithWeather();
    }
  }

  void _syncVideoWithWeather() {
    if (widget.weatherData == null) return;

    final cond = widget.weatherData!.condition.toLowerCase();
    final cloudCover = widget.weatherData!.cloud_cover;
    final rainProb = _calculatedRainProb;

    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    bool isDay = true;
    if (widget.weatherData!.sunrise != 0) {
      isDay = nowUnix >= widget.weatherData!.sunrise && nowUnix <= widget.weatherData!.sunset;
    } else {
      final hour = DateTime.now().hour;
      isDay = hour >= 6 && hour <= 18;
    }

    String targetVideo = "sunny";

    if (cond.contains("rain") || cond.contains("drizzle") || cond.contains("storm") || cond.contains("thunderstorm") || widget.weatherData!.rainfall > 0.0) {
      targetVideo = "rain";
    } else if (cloudCover > 55) {
      targetVideo = "cloudy";
    } else if (isDay && cloudCover < 55 && rainProb < 20) {
      targetVideo = "sunny";
    } else if (!isDay) {
      targetVideo = "night";
    }

    if (targetVideo != _activeVideo) {
      setState(() {
        _activeVideo = targetVideo;
      });

      // Play the visible video, pause others
      _playActiveOnly();
    } else {
      // Just ensure the active video is playing
      _playActiveOnly();
    }
  }

  void _playActiveOnly() {
    if (!_initialized) return;

    if (_activeVideo == "sunny") {
      _sunnyController?.play();
      _cloudyController?.pause();
      _rainController?.pause();
      _nightController?.pause();
    } else if (_activeVideo == "cloudy") {
      _sunnyController?.pause();
      _cloudyController?.play();
      _rainController?.pause();
      _nightController?.pause();
    } else if (_activeVideo == "rain") {
      _sunnyController?.pause();
      _cloudyController?.pause();
      _rainController?.play();
      _nightController?.pause();
    } else if (_activeVideo == "night") {
      _sunnyController?.pause();
      _cloudyController?.pause();
      _rainController?.pause();
      _nightController?.play();
    }
  }

  @override
  void dispose() {
    _sunnyController?.dispose();
    _cloudyController?.dispose();
    _rainController?.dispose();
    _nightController?.dispose();
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
            // Dynamic Video Background Hero Card
            Container(
              height: 240,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  // Preloaded Video Players with 1500ms CrossFade Opacity transition
                  if (_initialized) ...[
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: _activeVideo == "sunny" ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeInOut,
                        child: SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _sunnyController!.value.size.width > 0 ? _sunnyController!.value.size.width : 16,
                              height: _sunnyController!.value.size.height > 0 ? _sunnyController!.value.size.height : 9,
                              child: VideoPlayer(_sunnyController!),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: _activeVideo == "cloudy" ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeInOut,
                        child: SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _cloudyController!.value.size.width > 0 ? _cloudyController!.value.size.width : 16,
                              height: _cloudyController!.value.size.height > 0 ? _cloudyController!.value.size.height : 9,
                              child: VideoPlayer(_cloudyController!),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: _activeVideo == "rain" ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeInOut,
                        child: SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _rainController!.value.size.width > 0 ? _rainController!.value.size.width : 16,
                              height: _rainController!.value.size.height > 0 ? _rainController!.value.size.height : 9,
                              child: VideoPlayer(_rainController!),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: _activeVideo == "night" ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeInOut,
                        child: SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _nightController!.value.size.width > 0 ? _nightController!.value.size.width : 16,
                              height: _nightController!.value.size.height > 0 ? _nightController!.value.size.height : 9,
                              child: VideoPlayer(_nightController!),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Gradient overlay to ensure text readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
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
                      child: Row(
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
            fontWeight: FontWeight.bold,
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
