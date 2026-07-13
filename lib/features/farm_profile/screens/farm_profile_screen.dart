import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../models/farm_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/app_button.dart';

class FarmProfileScreen extends StatefulWidget {
  const FarmProfileScreen({super.key});

  @override
  State<FarmProfileScreen> createState() => _FarmProfileScreenState();
}

class _FarmProfileScreenState extends State<FarmProfileScreen> {
  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _acresController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _soilController = TextEditingController();
  bool _isLoading = false;
  String _error = "";

  @override
  void dispose() {
    _farmNameController.dispose();
    _acresController.dispose();
    _locationController.dispose();
    _soilController.dispose();
    super.dispose();
  }

  void _handleAddFarm(String langCode) async {
    final name = _farmNameController.text.trim();
    final acresStr = _acresController.text.trim();
    final location = _locationController.text.trim();
    final soil = _soilController.text.trim();

    if (name.isEmpty || acresStr.isEmpty || location.isEmpty) {
      setState(() {
        _error = langCode == 'kn-IN'
            ? "ದಯವಿಟ್ಟು ಎಲ್ಲಾ ಕಡ್ಡಾಯ ಕ್ಷೇತ್ರಗಳನ್ನು ಭರ್ತಿ ಮಾಡಿ"
            : (langCode == 'hi-IN' ? "कृपया सभी अनिवार्य फ़ील्ड भरें" : "Please fill in plot name, acres, and location");
      });
      return;
    }

    final double? acres = double.tryParse(acresStr);
    if (acres == null || acres <= 0) {
      setState(() {
        _error = langCode == 'kn-IN'
            ? "ಎಕರೆ ಸಂಖ್ಯೆ ಸರಿಯಾಗಿ ನಮೂದಿಸಿ"
            : (langCode == 'hi-IN' ? "एकड़ संख्या सही ढंग से दर्ज करें" : "Please enter a valid size in acres");
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
    final String farmId = const Uuid().v4();

    final farm = FarmModel(
      farmId: farmId,
      farmName: name,
      crop: "Grapes",
      acres: acres,
      location: location,
      soilType: soil,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await firestoreService.addFarm(uid, farm);

    setState(() {
      _isLoading = false;
    });

    // Go to Home
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('farm_profile', langCode)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppTranslations.translate('farm_desc', langCode),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 24),

              // Farm Name Field
              TextField(
                controller: _farmNameController,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                decoration: InputDecoration(
                  labelText: AppTranslations.translate('farm_name', langCode),
                  prefixIcon: const Icon(Icons.wb_twilight, color: AppColors.primaryGreen),
                  hintText: "e.g. Basveshwar Plot 1",
                ),
              ),
              const SizedBox(height: 18),

              // Crop Field (Fixed to "Grapes" as per instructions)
              TextField(
                enabled: false,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textLight),
                decoration: InputDecoration(
                  labelText: AppTranslations.translate('crop', langCode),
                  prefixIcon: const Icon(Icons.eco, color: AppColors.accentPurple),
                  hintText: "Grapes (द्राक्ष / द्राक्षी)",
                ),
              ),
              const SizedBox(height: 18),

              // Acres Field
              TextField(
                controller: _acresController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                decoration: InputDecoration(
                  labelText: AppTranslations.translate('acres', langCode),
                  prefixIcon: const Icon(Icons.square_foot, color: AppColors.primaryGreen),
                  hintText: "e.g. 3.5",
                ),
              ),
              const SizedBox(height: 18),

              // Location Field
              TextField(
                controller: _locationController,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                decoration: InputDecoration(
                  labelText: "Plot Location",
                  prefixIcon: const Icon(Icons.map, color: AppColors.primaryGreen),
                  hintText: "e.g. Soudi village",
                ),
              ),
              const SizedBox(height: 18),

              // Soil Type Field
              TextField(
                controller: _soilController,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                decoration: InputDecoration(
                  labelText: AppTranslations.translate('soil_type', langCode),
                  prefixIcon: const Icon(Icons.layers, color: AppColors.primaryGreen),
                  hintText: "e.g. Black soil / Red soil",
                ),
              ),
              const SizedBox(height: 24),

              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _error,
                    style: const TextStyle(color: AppColors.errorRed, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),

              const SizedBox(height: 12),

              AppButton(
                text: AppTranslations.translate('add_farm', langCode),
                icon: Icons.add_business,
                isLoading: _isLoading,
                onPressed: () => _handleAddFarm(langCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
