import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../models/farmer_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class FarmerProfileScreen extends StatefulWidget {
  const FarmerProfileScreen({super.key});

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _villageController = TextEditingController();
  bool _aiConsent = true;
  bool _dataShareConsent = true;
  bool _anonSharing = true;
  bool _isLoading = false;
  String _error = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      if (firestoreService.cachedFarmer != null) {
        final farmer = firestoreService.cachedFarmer!;
        setState(() {
          _nameController.text = farmer.name;
          _villageController.text = farmer.village;
          _aiConsent = farmer.aiTrainingConsent;
          _dataShareConsent = farmer.dataSharingConsent;
          _anonSharing = farmer.anonymousSharingAllowed;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  void _handleSaveProfile(String langCode) async {
    final name = _nameController.text.trim();
    final village = _villageController.text.trim();

    if (name.isEmpty || village.isEmpty) {
      setState(() {
        _error = langCode == 'kn-IN'
            ? "ಹೆಸರು ಮತ್ತು ಗ್ರಾಮದ ಹೆಸರನ್ನು ನಮೂದಿಸಿ"
            : (langCode == 'hi-IN' ? "नाम और गांव का नाम दर्ज करें" : "Please fill in your name and village");
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = "";
    });

    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    final String uid = authService.currentUid ?? "mock_farmer_patil";
    final String phone = authService.currentPhoneNumber ?? "+919876543210";

    final farmer = FarmerModel(
      farmerId: uid,
      name: name,
      phone: phone,
      village: village,
      preferredLanguage: langCode,
      aiTrainingConsent: _aiConsent,
      dataSharingConsent: _dataShareConsent,
      anonymousSharingAllowed: _anonSharing,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await firestoreService.saveFarmerProfile(farmer);

    setState(() {
      _isLoading = false;
    });

    // Check if farmer has at least one plot/farm
    if (!mounted) return;
    if (firestoreService.cachedFarms.isNotEmpty) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      Navigator.pushReplacementNamed(context, '/farm_profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('farmer_profile', langCode)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppTranslations.translate('farmer_desc', langCode),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 24),

              // Name Field
              TextField(
                controller: _nameController,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                decoration: InputDecoration(
                  labelText: AppTranslations.translate('farmer_name', langCode),
                  prefixIcon: const Icon(Icons.person, color: AppColors.primaryGreen),
                ),
              ),
              const SizedBox(height: 18),

              // Village Field
              TextField(
                controller: _villageController,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                decoration: InputDecoration(
                  labelText: AppTranslations.translate('village', langCode),
                  prefixIcon: const Icon(Icons.location_on, color: AppColors.primaryGreen),
                ),
              ),
              const SizedBox(height: 24),

              // Privacy Consent Card
              AppCard(
                color: AppColors.primaryLight.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.translate('consent_title', langCode),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.earthyBrown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Your farm data is private. You can choose whether your data can be used to improve future AI suggestions.",
                      style: TextStyle(fontSize: 13, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 14),

                    // Consent 1: AI suggestions
                    SwitchListTile(
                      value: _aiConsent,
                      activeThumbColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        AppTranslations.translate('ai_consent_label', langCode),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      onChanged: (val) => setState(() => _aiConsent = val),
                    ),

                    // Consent 2: Data sharing
                    SwitchListTile(
                      value: _dataShareConsent,
                      activeThumbColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        AppTranslations.translate('data_sharing_label', langCode),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      onChanged: (val) => setState(() => _dataShareConsent = val),
                    ),

                    // Consent 3: Anonymous Export
                    SwitchListTile(
                      value: _anonSharing,
                      activeThumbColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        AppTranslations.translate('anon_sharing_label', langCode),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      onChanged: (val) => setState(() => _anonSharing = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_error.isNotEmpty)
                Text(
                  _error,
                  style: const TextStyle(color: AppColors.errorRed, fontSize: 14, fontWeight: FontWeight.bold),
                ),

              const SizedBox(height: 30),

              AppButton(
                text: AppTranslations.translate('save_profile', langCode),
                icon: Icons.save,
                isLoading: _isLoading,
                onPressed: () => _handleSaveProfile(langCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
