import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../services/firestore_service.dart';
import '../../../services/analytics_service.dart';
import '../../../widgets/app_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/diary_entry_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../../services/location_service.dart';
import '../../../services/weather_service.dart';
import '../../../widgets/live_vineyard_hero_card.dart';
import '../../draksha_ai/services/draksha_api_client.dart';

// Import features to embed inside bottom navigation tabs
import 'diary_history_screen.dart';
import '../../analytics/screens/expense_analytics_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../settings/screens/profile_settings_screen.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _currentTab = 0;
  String _selectedFarmId = "plot_1";
  DateTime? _lastPressedAt;
  WeatherData? _weatherData;
  bool _loadingWeather = false;

  Map<String, dynamic>? _cachedPrediction;
  String _lastUpdatedText = "Last updated just now";
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 5), () {
        _triggerTestNotification();
      });
      _initLocation();
    });
  }

  Future<void> _initLocation() async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final farmerId = firestoreService.cachedFarmer?.farmerId ?? FirebaseAuth.instance.currentUser?.uid ?? "";
      if (farmerId.isNotEmpty) {
        await LocationService.checkAndSaveLocation(farmerId);
        // Refresh local cache to ensure latest coords are saved/synced
        await firestoreService.syncOfflineData(farmerId);
      }
      _loadActivePlotData();
    } catch (e) {
      debugPrint("HomeDashboard location init error: $e");
      _loadActivePlotData();
    }
  }

  Future<void> _loadActivePlotData() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final farmerId = firestoreService.cachedFarmer?.farmerId ?? FirebaseAuth.instance.currentUser?.uid ?? "";
    if (farmerId.isEmpty) return;

    final cacheKey = "prediction_cache_$_selectedFarmId";
    final prefs = await SharedPreferences.getInstance();

    // 1. Try loading cached weather first to guarantee zero delay & offline resilience
    final cachedStr = prefs.getString(cacheKey);
    final cachedTime = prefs.getInt("${cacheKey}_time");
    if (cachedStr != null && cachedTime != null) {
      try {
        final decoded = jsonDecode(cachedStr);
        final ageMinutes = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cachedTime)).inMinutes;
        setState(() {
          _cachedPrediction = decoded;
          _lastUpdatedText = "Last updated $ageMinutes mins ago";
          if (decoded['weather_raw'] != null) {
            _weatherData = _parseWeatherData(decoded['weather_raw']);
          }
        });
      } catch (e) {
        debugPrint("Error loading cached prediction: $e");
      }
    }

    setState(() {
      _loadingWeather = true;
      _isOffline = false;
    });

    try {
      double? lat;
      double? lon;
      String location = "Sangli";
      if (firestoreService.cachedFarms.isNotEmpty) {
        final activeFarm = firestoreService.cachedFarms.firstWhere(
          (f) => f.farmId == _selectedFarmId,
          orElse: () => firestoreService.cachedFarms.first,
        );
        if (activeFarm.location.isNotEmpty) {
          location = activeFarm.location;
          if (location.contains(",")) {
            final parts = location.split(",");
            lat = double.tryParse(parts[0].trim());
            lon = double.tryParse(parts[1].trim());
          }
        }
      } else if (firestoreService.cachedFarmer?.village.isNotEmpty ?? false) {
        location = firestoreService.cachedFarmer!.village;
      }

      // Call our prediction engine which also retrieves fresh coordinate weather
      final result = await DrakshaApiClient.predictDisease(
        uid: farmerId,
        location: location,
        lat: lat,
        lon: lon,
      );

      // Cache the result
      await prefs.setString(cacheKey, jsonEncode(result));
      await prefs.setInt("${cacheKey}_time", DateTime.now().millisecondsSinceEpoch);

      setState(() {
        _cachedPrediction = result;
        _lastUpdatedText = "Last updated just now";
        if (result['weather_raw'] != null) {
          _weatherData = _parseWeatherData(result['weather_raw']);
        }
        _loadingWeather = false;
      });
    } catch (e) {
      debugPrint("Failed loading dashboard weather: $e");
      setState(() {
        _loadingWeather = false;
        _isOffline = true;
        if (_cachedPrediction != null) {
          final cacheTimeVal = prefs.getInt("${cacheKey}_time") ?? DateTime.now().millisecondsSinceEpoch;
          final ageMinutes = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cacheTimeVal)).inMinutes;
          _lastUpdatedText = "Showing last available weather ($ageMinutes mins ago)";
        } else {
          _lastUpdatedText = "Showing last available weather";
        }
      });
    }
  }

  WeatherData _parseWeatherData(Map<String, dynamic> data) {
    final main = data['main'] ?? {};
    final temp = (main['temp'] as num?)?.toDouble() ?? 27.0;
    final humidity = (main['humidity'] as num?)?.toInt() ?? 65;
    final wind = (data['wind']?['speed'] as num?)?.toDouble() ?? 12.0;
    final condition = (data['weather'] != null && data['weather'].isNotEmpty)
        ? data['weather'][0]['main'].toString()
        : "Sunny";
    final cloudCover = (data['clouds']?['all'] as num?)?.toInt() ?? 0;

    double rain = 0.0;
    if (data.containsKey('rain') && data['rain'].containsKey('1h')) {
      rain = (data['rain']['1h'] as num).toDouble();
    }

    return WeatherData(
      temperature: temp,
      humidity: humidity,
      rainfall: rain,
      windSpeed: wind,
      condition: condition,
      forecast: "Similar conditions expected for the next 24 hours.",
      location: data['name']?.toString() ?? "Local farm",
      cloud_cover: cloudCover,
    );
  }

  Future<void> _handleBackPress(bool didPop) async {
    if (didPop) return;
    if (_currentTab != 0) {
      setState(() {
        _currentTab = 0;
      });
      return;
    }
    
    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrDelayIsGreaterThan2Seconds =
        _lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2);
    
    if (backButtonHasNotBeenPressedOrDelayIsGreaterThan2Seconds) {
      _lastPressedAt = now;
      final langCode = Provider.of<LanguageNotifier>(context, listen: false).currentLanguage;
      final warningMsg = langCode == 'kn-IN'
          ? "ಹೊರಹೋಗಲು ಮತ್ತೊಮ್ಮೆ ಬ್ಯಾಕ್ ಬಟನ್ ಒತ್ತಿ"
          : (langCode == 'hi-IN' ? "बाहर निकलने के लिए फिर से बैक बटन दबाएं" : "Press back again to exit");
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warningMsg),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      await SystemNavigator.pop();
    }
  }

  // Handles switching screens inside bottom nav bar
  Widget _buildBody(String langCode) {
    switch (_currentTab) {
      case 0:
        return _buildHomeTab(langCode);
      case 1:
        return DiaryHistoryScreen(selectedFarmId: _selectedFarmId);
      case 2:
        return ExpenseAnalyticsScreen(selectedFarmId: _selectedFarmId);
      case 3:
        return ReportsScreen(selectedFarmId: _selectedFarmId);
      case 4:
        return const ProfileSettingsScreen();
      default:
        return _buildHomeTab(langCode);
    }
  }

  Widget _buildHomeTab(String langCode) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final farmerName = firestoreService.cachedFarmer?.name ?? "Farmer";

    // Auto-select first available farm if the selected farm ID is not in the cached farms list
    if (firestoreService.cachedFarms.isNotEmpty &&
        !firestoreService.cachedFarms.any((f) => f.farmId == _selectedFarmId)) {
      _selectedFarmId = firestoreService.cachedFarms.first.farmId;
    }
    
    // Dynamic summary calculations
    final summary = AnalyticsService.generateSummary(
      firestoreService.cachedDiary.where((e) => e.farmId == _selectedFarmId).toList(),
      _selectedFarmId,
      langCode,
    );

    final todayStr = DateFormat.yMMMMd(langCode == 'kn-IN' ? 'kn' : (langCode == 'hi-IN' ? 'hi' : 'en')).format(DateTime.now());

    return RefreshIndicator(
      onRefresh: () async {
        await firestoreService.syncOfflineData(firestoreService.cachedFarmer?.farmerId ?? "mock_farmer");
        await _loadActivePlotData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section: Greeting & Plot Switcher
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        langCode == 'kn-IN' ? "ನಮಸ್ತೆ, $farmerName" : (langCode == 'hi-IN' ? "नमस्ते, $farmerName" : "Namaste, $farmerName"),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.earthyBrown,
                        ),
                      ),
                      Text(
                        todayStr,
                        style: const TextStyle(fontSize: 14, color: AppColors.textLight, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                // Custom Plot Switcher Dropdown
                if (firestoreService.cachedFarms.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedFarmId,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
                      underline: const SizedBox(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                           setState(() {
                            _selectedFarmId = newValue;
                          });
                          _loadActivePlotData();
                        }
                      },
                      items: firestoreService.cachedFarms.map<DropdownMenuItem<String>>((farm) {
                        return DropdownMenuItem<String>(
                          value: farm.farmId,
                          child: Text(
                            farm.farmName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Status Panel: Backup Indicator & Monthly Expense Summary
             LiveVineyardHeroCard(
              plotName: firestoreService.cachedFarms.isNotEmpty
                  ? firestoreService.cachedFarms.firstWhere(
                      (f) => f.farmId == _selectedFarmId,
                      orElse: () => firestoreService.cachedFarms.first,
                    ).farmName
                  : "My Vineyard",
              weatherData: _weatherData,
              smartStatus: _cachedPrediction?['smartStatus'] ?? "Excellent Growing Conditions",
              aiInsight: _cachedPrediction?['aiInsight'] ?? "Analyzing vine canopy data & weather models...",
              lastUpdatedText: _lastUpdatedText,
              isOffline: _isOffline,
            ),
            const SizedBox(height: 24),

            // Disease Outbreak Advisory Alert Stream
            _buildDiseaseAlertAdvisory(langCode, firestoreService),

            // Draksha AI Banner
            AppCard(
              onTap: () => Navigator.pushNamed(context, '/chatbot', arguments: _selectedFarmId),
              color: AppColors.accentPurple.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.2)),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.psychology, color: AppColors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          langCode == 'kn-IN' ? "ದ್ರಾಕ್ಷಾ AI ಸಹಾಯಕ" : (langCode == 'hi-IN' ? "द्राक्षा AI सहायक" : "Draksha AI Assistant"),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          langCode == 'kn-IN'
                              ? "ನಿಮ್ಮ ಹಳೆಯ ದಾಖಲೆಗಳು ಮತ್ತು ರೋಗಗಳ ಬಗ್ಗೆ ಕೇಳಿ"
                              : (langCode == 'hi-IN'
                                  ? "अपने पुराने रिकॉर्ड और बीमारियों के बारे में पूछें"
                                  : "Query your spraying history & grape viticulture advice"),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.accentPurple),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Navigation Matrix Grid Section (10 Large visual action modules)
            const Text(
              "Quick Operations",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.earthyBrown,
              ),
            ),
            const SizedBox(height: 14),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.3,
              children: [
                _buildGridCard(
                  title: AppTranslations.translate('add_today_diary', langCode),
                  icon: Icons.edit_note,
                  color: AppColors.primaryLight,
                  iconColor: AppColors.primaryGreen,
                  onTap: () => Navigator.pushNamed(context, '/add_diary', arguments: _selectedFarmId),
                ),
                _buildGridCard(
                  title: AppTranslations.translate('record_voice_note', langCode),
                  icon: Icons.mic,
                  color: const Color(0xFFF3E5F5),
                  iconColor: AppColors.accentPurple,
                  onTap: () => Navigator.pushNamed(context, '/voice_record', arguments: _selectedFarmId),
                ),
                _buildGridCard(
                  title: AppTranslations.translate('add_expense', langCode),
                  icon: Icons.currency_rupee,
                  color: const Color(0xFFFFFDE7),
                  iconColor: Colors.amber.shade800,
                  onTap: () => Navigator.pushNamed(context, '/manual_expense', arguments: _selectedFarmId),
                ),
                _buildGridCard(
                  title: AppTranslations.translate('scan_bill', langCode),
                  icon: Icons.document_scanner,
                  color: const Color(0xFFE3F2FD),
                  iconColor: Colors.blue.shade700,
                  onTap: () => Navigator.pushNamed(context, '/bill_scanner', arguments: _selectedFarmId),
                ),
                _buildGridCard(
                  title: AppTranslations.translate('add_photo', langCode),
                  icon: Icons.add_a_photo,
                  color: const Color(0xFFE0F2F1),
                  iconColor: Colors.teal.shade700,
                  onTap: () => Navigator.pushNamed(context, '/photo_gallery', arguments: _selectedFarmId),
                ),
                _buildGridCard(
                  title: langCode == 'kn-IN' ? "ಟರ್ನೋವರ್ ಟ್ರ್ಯಾಕರ್" : (langCode == 'hi-IN' ? "टर्नओवर ट्रैकर" : "Turnover Tracker"),
                  icon: Icons.assignment_turned_in,
                  color: const Color(0xFFE8F5E9),
                  iconColor: AppColors.successGreen,
                  onTap: () => Navigator.pushNamed(context, '/turnover', arguments: _selectedFarmId),
                ),
                _buildGridCard(
                  title: AppTranslations.translate('view_farm_history', langCode),
                  icon: Icons.history,
                  color: const Color(0xFFEFEBE9),
                  iconColor: AppColors.earthyBrown,
                  onTap: () => setState(() => _currentTab = 1),
                ),
                _buildGridCard(
                  title: AppTranslations.translate('expense_analytics', langCode),
                  icon: Icons.bar_chart,
                  color: const Color(0xFFECEFF1),
                  iconColor: Colors.blueGrey.shade700,
                  onTap: () => setState(() => _currentTab = 2),
                ),
                _buildGridCard(
                  title: AppTranslations.translate('reports', langCode),
                  icon: Icons.assignment,
                  color: const Color(0xFFFBE9E7),
                  iconColor: Colors.deepOrange.shade700,
                  onTap: () => setState(() => _currentTab = 3),
                ),
                _buildGridCard(
                  title: AppTranslations.translate('backup_status', langCode),
                  icon: Icons.cloud_sync,
                  color: const Color(0xFFE8F5E9),
                  iconColor: AppColors.successGreen,
                  onTap: () => Navigator.pushNamed(context, '/backup_status'),
                ),
                _buildGridCard(
                  title: "Consent & Privacy",
                  icon: Icons.privacy_tip,
                  color: const Color(0xFFFFF3E0),
                  iconColor: Colors.orange.shade800,
                  onTap: () => Navigator.pushNamed(context, '/privacy_consent'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleBackPress(didPop),
      child: Scaffold(
        body: SafeArea(child: _buildBody(langCode)),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) {
            setState(() {
              _currentTab = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: AppTranslations.translate('home', langCode),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.menu_book),
              label: AppTranslations.translate('diary', langCode),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.pie_chart),
              label: AppTranslations.translate('analytics', langCode),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.assessment),
              label: AppTranslations.translate('reports', langCode),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: AppTranslations.translate('profile', langCode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseAlertAdvisory(String langCode, FirestoreService firestoreService) {
    final uid = firestoreService.cachedFarmer?.farmerId ?? "mock_farmer";
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('alerts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final String disease = data['disease'] ?? 'Unknown';
        final String riskLevel = data['riskLevel'] ?? 'Low';
        final String recommended = data['recommendedSpray'] ?? 'None';
        final String explanation = data['explanation'] ?? '';

        final isHigh = riskLevel.toLowerCase() == 'high';
        final Color cardColor = isHigh ? AppColors.errorRed.withOpacity(0.08) : AppColors.softYellow.withOpacity(0.15);
        final Color borderColor = isHigh ? AppColors.errorRed.withOpacity(0.3) : AppColors.softYellow.withOpacity(0.5);
        final Color textColor = isHigh ? AppColors.errorRed : AppColors.earthyBrown;
        final IconData icon = isHigh ? Icons.warning_amber_rounded : Icons.info_outline;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: AppCard(
            color: cardColor,
            border: Border.all(color: borderColor, width: 1.5),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: textColor, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      langCode == 'kn-IN' ? "⚠️ ರೋಗದ ಎಚ್ಚರಿಕೆ" : (langCode == 'hi-IN' ? "⚠️ बीमारी की चेतावनी" : "⚠️ Disease Alert"),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: textColor.withOpacity(0.6), size: 18),
                      onPressed: () async {
                        await doc.reference.delete();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  langCode == 'kn-IN'
                      ? "ಹೆಚ್ಚಿನ ಅಪಾಯ: $disease ($riskLevel Risk)"
                      : (langCode == 'hi-IN'
                          ? "उच्च जोखिम: $disease ($riskLevel Risk)"
                          : "High Risk of $disease detected in the next 5 days."),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  explanation,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                ),
                const Divider(height: 20, thickness: 0.5),
                Row(
                  children: [
                    Icon(Icons.healing_outlined, color: textColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                          children: [
                            TextSpan(
                              text: langCode == 'kn-IN' ? "ಶಿಫಾರಸು ಮಾಡಿದ ಔಷಧಿ: " : (langCode == 'hi-IN' ? "अनुशंसित छिड़काव: " : "Recommended Spray: "),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: recommended,
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _triggerTestNotification() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    final farmerId = firebaseUid ?? firestoreService.cachedFarmer?.farmerId ?? "mock_farmer";

    // Prevent trigger loop
    final prefs = await SharedPreferences.getInstance();
    final hasRun = prefs.getBool('test_notification_triggered_v4') ?? false;
    if (hasRun) return;
    await prefs.setBool('test_notification_triggered_v4', true);

    debugPrint("AUTO-TEST: Running automatic disease alert trigger simulation...");

    final testEntry = DiaryEntryModel(
      entryId: "test_auto_alert_${DateTime.now().millisecondsSinceEpoch}",
      farmerId: farmerId,
      farmId: _selectedFarmId,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      cropStage: "Flowering",
      workType: "Spraying",
      languageCode: "en-US",
      inputType: "text",
      cleanedText: "I observed Powdery Mildew symptoms on my grape leaves.",
      originalText: "I observed Powdery Mildew symptoms on my grape leaves.",
      photos: [],
      expenses: [],
      structuredData: StructuredData(
        pesticides: [],
        fertilizers: [],
        labour: {},
        irrigation: {},
        expenses: [],
        observations: ["Powdery Mildew"],
        followUpActions: [],
        tags: [],
      ),
      totalExpense: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      missingFields: [],
    );

    await firestoreService.saveDiaryEntry(farmerId, _selectedFarmId, testEntry);
    debugPrint("AUTO-TEST: Diary entry stored. AI advisory analysis triggered successfully.");
  }
}
