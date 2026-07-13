import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../services/firestore_service.dart';
import '../../../services/analytics_service.dart';
import '../../../widgets/app_card.dart';

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
      onRefresh: () => firestoreService.syncOfflineData(firestoreService.cachedFarmer?.farmerId ?? "mock_farmer"),
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
            AppCard(
              color: AppColors.primaryGreen,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_done, color: AppColors.softYellow, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            AppTranslations.translate('backup_msg', langCode),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        "ONLINE",
                        style: TextStyle(
                          color: AppColors.softYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppTranslations.translate('month_expense', langCode).toUpperCase(),
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "₹${summary.monthTotal.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "This Year: ₹${summary.yearTotal.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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
}
