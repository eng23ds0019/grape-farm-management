import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class PrivacyConsentScreen extends StatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _aiTrainingConsent = true;
  bool _dataSharingConsent = true;
  bool _anonymousSharing = true;

  @override
  void initState() {
    super.initState();
    final service = Provider.of<FirestoreService>(context, listen: false);
    final farmer = service.cachedFarmer;
    if (farmer != null) {
      _aiTrainingConsent = farmer.aiTrainingConsent;
      _dataSharingConsent = farmer.dataSharingConsent;
      _anonymousSharing = farmer.anonymousSharingAllowed;
    }
  }

  Future<void> _saveConsents(FirestoreService service) async {
    final oldFarmer = service.cachedFarmer;
    if (oldFarmer != null) {
      final updated = oldFarmer.copyWith(
        aiTrainingConsent: _aiTrainingConsent,
        dataSharingConsent: _dataSharingConsent,
        anonymousSharingAllowed: _anonymousSharing,
        updatedAt: DateTime.now(),
      );

      await service.saveFarmerProfile(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Privacy and AI consent choices saved!")),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<LanguageNotifier>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text("Data Consent & AI Safety"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Shield Visual Card
            AppCard(
              color: AppColors.primaryLight,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security, color: AppColors.white, size: 48),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Your Farm Data is Safe & Secure",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Soudi Farming protects your records. We only use anonymized aggregated metrics to construct AI crop predictions. You are in full control.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Manage Permissions",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.earthyBrown,
              ),
            ),
            const SizedBox(height: 12),

            // Toggle 1: AI Training
            AppCard(
              color: AppColors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "AI Crop Advisory Training",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Allows our machine learning models to study your anonymized spraying quantities to build smarter pest and disease warnings.",
                          style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _aiTrainingConsent,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (val) => setState(() => _aiTrainingConsent = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Toggle 2: Researcher Sharing
            AppCard(
              color: AppColors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Agricultural Research Collaboration",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Shares your grape yields and pruning schedules with agricultural university researchers to study soil quality improvements.",
                          style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _dataSharingConsent,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (val) => setState(() => _dataSharingConsent = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Toggle 3: Open Data Export
            AppCard(
              color: AppColors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Anonymous Data Export Dataset",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Includes your anonymous data in regional agricultural summaries. Toggling this off hides all items from public export dashboards completely.",
                          style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _anonymousSharing,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (val) => setState(() => _anonymousSharing = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Security Details Alert
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Data protection complies with the highest digital privacy protocols. Your farm logs will never be sold or leased to third-party commercial advertisers.",
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade800, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Save Preferences Button
            AppButton(
              text: "CONFIRM MY CHOICES",
              icon: Icons.check_circle_outline,
              onPressed: () => _saveConsents(firestoreService),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
