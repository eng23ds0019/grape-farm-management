import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/constants.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedCode = "en-IN";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = Provider.of<LanguageNotifier>(context, listen: false);
      setState(() {
        _selectedCode = notifier.currentLanguage;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageNotifier = Provider.of<LanguageNotifier>(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Brand Grape Logo Mock
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco,
                    size: 54,
                    color: AppColors.accentPurple,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppTranslations.translate('language_select', _selectedCode),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.earthyBrown,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppTranslations.translate('language_desc', _selectedCode),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 40),

              // Language Selection Cards
              Expanded(
                child: ListView(
                  children: AppConstants.languages.map((lang) {
                    final isSelected = _selectedCode == lang['code'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: AppCard(
                        onTap: () {
                          setState(() {
                            _selectedCode = lang['code']!;
                          });
                        },
                        border: isSelected
                            ? Border.all(color: AppColors.primaryGreen, width: 2.5)
                            : Border.all(color: AppColors.borderLight, width: 1),
                        color: isSelected
                            ? AppColors.primaryLight
                            : AppColors.white,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang['nativeName']!,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? AppColors.primaryGreen
                                        : AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lang['name']!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected
                                        ? AppColors.primaryGreen.withValues(alpha: 0.8)
                                        : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primaryGreen,
                                size: 30,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Submit Button
              AppButton(
                text: AppTranslations.translate('next', _selectedCode),
                icon: Icons.arrow_forward,
                onPressed: () async {
                  await languageNotifier.setLanguage(_selectedCode);
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
