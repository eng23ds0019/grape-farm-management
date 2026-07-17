import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/constants.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../models/farmer_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../../../services/openai_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _villageController;
  late TextEditingController _phoneController;
  late TextEditingController _openAiApiKeyController;

  // Smart Notifications Settings Flags
  bool _diseaseAlerts = true;
  bool _weatherAlerts = true;
  bool _sprayReminders = true;
  bool _expenseAlerts = true;
  bool _profitAlerts = true;
  bool _harvestAlerts = true;
  bool _aiRecommendations = true;

  @override
  void initState() {
    super.initState();
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final farmer = firestoreService.cachedFarmer;

    _nameController = TextEditingController(text: farmer?.name ?? "");
    _villageController = TextEditingController(text: farmer?.village ?? "");
    _phoneController = TextEditingController(text: farmer?.phone ?? "");
    _openAiApiKeyController = TextEditingController();
    _loadApiKey();
    _loadNotificationSettings();
  }

  void _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _diseaseAlerts = prefs.getBool('ns_diseaseAlerts') ?? true;
      _weatherAlerts = prefs.getBool('ns_weatherAlerts') ?? true;
      _sprayReminders = prefs.getBool('ns_sprayReminders') ?? true;
      _expenseAlerts = prefs.getBool('ns_expenseAlerts') ?? true;
      _profitAlerts = prefs.getBool('ns_profitAlerts') ?? true;
      _harvestAlerts = prefs.getBool('ns_harvestAlerts') ?? true;
      _aiRecommendations = prefs.getBool('ns_aiRecommendations') ?? true;
    });

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final farmer = firestoreService.cachedFarmer;
    if (farmer != null && !firestoreService.useMock) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(farmer.farmerId)
            .collection('settings')
            .doc('notifications')
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _diseaseAlerts = data['diseaseAlerts'] ?? _diseaseAlerts;
            _weatherAlerts = data['weatherAlerts'] ?? _weatherAlerts;
            _sprayReminders = data['sprayReminders'] ?? _sprayReminders;
            _expenseAlerts = data['expenseAlerts'] ?? _expenseAlerts;
            _profitAlerts = data['profitAlerts'] ?? _profitAlerts;
            _harvestAlerts = data['harvestAlerts'] ?? _harvestAlerts;
            _aiRecommendations = data['aiRecommendations'] ?? _aiRecommendations;
          });
          await prefs.setBool('ns_diseaseAlerts', _diseaseAlerts);
          await prefs.setBool('ns_weatherAlerts', _weatherAlerts);
          await prefs.setBool('ns_sprayReminders', _sprayReminders);
          await prefs.setBool('ns_expenseAlerts', _expenseAlerts);
          await prefs.setBool('ns_profitAlerts', _profitAlerts);
          await prefs.setBool('ns_harvestAlerts', _harvestAlerts);
          await prefs.setBool('ns_aiRecommendations', _aiRecommendations);
        }
      } catch (e) {
        debugPrint("Error loading notification settings: $e");
      }
    }
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ns_$key', value);

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final farmer = firestoreService.cachedFarmer;
    if (farmer != null && !firestoreService.useMock) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(farmer.farmerId)
            .collection('settings')
            .doc('notifications')
            .set({
          key: value,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error saving notification setting: $e");
      }
    }
  }

  void _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('openai_api_key') ?? "";
    setState(() {
      _openAiApiKeyController.text = key;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _villageController.dispose();
    _phoneController.dispose();
    _openAiApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileChanges(FirestoreService service, String langCode) async {
    if (_formKey.currentState!.validate()) {
      final oldFarmer = service.cachedFarmer;
      final updated = FarmerModel(
        farmerId: oldFarmer?.farmerId ?? 'mock_farmer_patil',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        village: _villageController.text.trim(),
        preferredLanguage: langCode,
        aiTrainingConsent: oldFarmer?.aiTrainingConsent ?? true,
        dataSharingConsent: oldFarmer?.dataSharingConsent ?? true,
        anonymousSharingAllowed: oldFarmer?.anonymousSharingAllowed ?? true,
        createdAt: oldFarmer?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await service.saveFarmerProfile(updated);

      // Save OpenAI API Key
      final prefs = await SharedPreferences.getInstance();
      final newKey = _openAiApiKeyController.text.trim();
      await prefs.setString('openai_api_key', newKey);
      OpenAiService.openAiApiKey = newKey;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile and system details saved successfully!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageNotifier = Provider.of<LanguageNotifier>(context);
    final langCode = languageNotifier.currentLanguage;
    final firestoreService = Provider.of<FirestoreService>(context);
    final authService = Provider.of<FirebaseAuthService>(context);

    final farmer = firestoreService.cachedFarmer;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(AppTranslations.translate('profile', langCode)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome badge
              _buildFarmerWelcomeCard(farmer, langCode),
              const SizedBox(height: 16),

              // Farmer Info Inputs
              AppCard(
                color: AppColors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Personal Profile Info",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                    ),
                    const Divider(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Farmer Name",
                        prefixIcon: Icon(Icons.person, color: AppColors.primaryGreen),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? "Please enter your name" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      enabled: false, // Phone shouldn't be edited manually if authenticated
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                        prefixIcon: Icon(Icons.phone, color: AppColors.primaryGreen),
                        fillColor: Colors.black12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _villageController,
                      decoration: const InputDecoration(
                        labelText: "Village Name",
                        prefixIcon: Icon(Icons.location_city, color: AppColors.primaryGreen),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? "Please enter your village" : null,
                    ),
                    const SizedBox(height: 18),
                    AppButton(
                      text: "SAVE PROFILE CHANGES",
                      icon: Icons.save,
                      onPressed: () => _saveProfileChanges(firestoreService, langCode),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Farm plots summary section
              _buildPlotsSection(firestoreService, langCode),
              const SizedBox(height: 16),

              // Language Selector inside Settings
              AppCard(
                color: AppColors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Application Language Choice",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Preferred Language:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButton<String>(
                            value: langCode,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                            onChanged: (String? val) {
                              if (val != null) {
                                languageNotifier.setLanguage(val);
                              }
                            },
                            items: AppConstants.languages.map((lang) {
                              return DropdownMenuItem(
                                value: lang['code']!,
                                child: Text(lang['nativeName']!),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Smart Notifications Settings
              AppCard(
                color: AppColors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Smart Notifications Settings",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                    ),
                    const Divider(height: 16),
                    _buildSwitchTile("Disease Alerts", "Receive warnings about Downy/Powdery Mildew outbreaks.", _diseaseAlerts, (val) {
                      setState(() => _diseaseAlerts = val);
                      _updateNotificationSetting('diseaseAlerts', val);
                    }),
                    _buildSwitchTile("Weather Warnings", "Rain forecast timing alerts for spray schedules.", _weatherAlerts, (val) {
                      setState(() => _weatherAlerts = val);
                      _updateNotificationSetting('weatherAlerts', val);
                    }),
                    _buildSwitchTile("Overdue Spray Reminders", "Get notified when a chemical was sprayed >10 days ago.", _sprayReminders, (val) {
                      setState(() => _sprayReminders = val);
                      _updateNotificationSetting('sprayReminders', val);
                    }),
                    _buildSwitchTile("Expense Alerts", "Warnings on cost trends and budget overruns.", _expenseAlerts, (val) {
                      setState(() => _expenseAlerts = val);
                      _updateNotificationSetting('expenseAlerts', val);
                    }),
                    _buildSwitchTile("Profit Insights", "Predictive profit estimation increases.", _profitAlerts, (val) {
                      setState(() => _profitAlerts = val);
                      _updateNotificationSetting('profitAlerts', val);
                    }),
                    _buildSwitchTile("Harvest Alerts", "Crop staging advisory alerts.", _harvestAlerts, (val) {
                      setState(() => _harvestAlerts = val);
                      _updateNotificationSetting('harvestAlerts', val);
                    }),
                    _buildSwitchTile("AI Pathologist Recommendations", "Daily treatment chemistry dose advice.", _aiRecommendations, (val) {
                      setState(() => _aiRecommendations = val);
                      _updateNotificationSetting('aiRecommendations', val);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Database Live/Mock Config toggler
              AppCard(
                color: AppColors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "System Configurations",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                    ),
                    const Divider(height: 16),

                    // Mock Switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Offline Mock Database Mode",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Operates locally using SharedPreferences without a live Firebase network.",
                                style: TextStyle(fontSize: 11, color: AppColors.textLight),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: firestoreService.useMock,
                          activeThumbColor: AppColors.primaryGreen,
                          onChanged: (val) {
                            firestoreService.setMockMode(val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(val ? "Switched to Offline Mock Mode" : "Switched to Live Firebase Connection")),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // OpenAI API Key Input Field
                    const Text(
                      "OpenAI API Key (Whisper & OCR)",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _openAiApiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: "sk-proj-...",
                        prefixIcon: Icon(Icons.vpn_key, color: AppColors.primaryGreen),
                        helperText: "Enter your OpenAI key for real-time receipt parsing & audio transcription. Tap 'SAVE CONFIGURATIONS' below to apply.",
                        helperMaxLines: 2,
                      ),
                    ),
                    const Divider(height: 16),

                    // Change Password settings link
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock, color: AppColors.primaryGreen),
                      title: const Text("Change Account Password", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      subtitle: const Text("Update your secure login password.", style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pushNamed(context, '/change_password');
                      },
                    ),
                    const Divider(height: 16),

                    // Consent settings link
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.privacy_tip, color: AppColors.accentPurple),
                      title: const Text("AI Consent & Data Privacy", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      subtitle: const Text("Control how crop data is analyzed for AI yield models.", style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pushNamed(context, '/privacy_consent');
                      },
                    ),
                    const Divider(height: 16),
                    AppButton(
                      text: "SAVE CONFIGURATIONS",
                      icon: Icons.save,
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final newKey = _openAiApiKeyController.text.trim();
                        await prefs.setString('openai_api_key', newKey);
                        OpenAiService.openAiApiKey = newKey;
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("System configurations saved successfully!")),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dangerous Zone
              AppCard(
                color: Colors.red.shade50.withValues(alpha: 0.4),
                border: Border.all(color: Colors.red.shade200, width: 1.0),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Data Management & Safety",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Wipe Local Cache Data", style: TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            foregroundColor: Colors.redAccent,
                          ),
                          onPressed: () => _confirmReset(context),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text("RESET APP", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    AppButton(
                      text: "LOG OUT FROM DEVICE",
                      icon: Icons.logout,
                      customColor: Colors.redAccent,
                      onPressed: () async {
                        await authService.logout();
                        if (!context.mounted) return;
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFarmerWelcomeCard(FarmerModel? farmer, String langCode) {
    return AppCard(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: AppColors.white, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmer?.name ?? "Grape Farmer",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                ),
                Text(
                  "Village: ${farmer?.village ?? 'Unknown'}",
                  style: TextStyle(fontSize: 13, color: AppColors.primaryGreen.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlotsSection(FirestoreService service, String langCode) {
    final farms = service.cachedFarms;

    return AppCard(
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Grape Plots",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primaryGreen, size: 28),
                onPressed: () {
                  Navigator.pushNamed(context, '/farm_profile');
                },
              ),
            ],
          ),
          const Divider(height: 10),
          if (farms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text("No grape farm plots set up yet. Tap '+' to add.", style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textLight)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: farms.length,
              separatorBuilder: (context, index) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final farm = farms[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.landscape, color: AppColors.primaryGreen),
                  title: Text(farm.farmName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  subtitle: Text("${farm.acres} Acres • Soil: ${farm.soilType}"),
                  trailing: const Icon(Icons.edit, size: 18, color: AppColors.textLight),
                  onTap: () {
                    // Quick edit
                    Navigator.pushNamed(context, '/farm_profile', arguments: farm);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Wipe Local Cache?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            "This will delete all offline caching, diary history, and profile records from SharedPreferences. Wiped data is unrecoverable if not synced with the cloud.",
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(Icons.close, size: 16),
              label: const Text("CANCEL"),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
              label: const Text("RESET ALL", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Application cache has been completely reset.")),
        );
        Navigator.pushReplacementNamed(context, '/'); // Reset back to Splash
      }
    }
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primaryGreen,
          title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          value: value,
          onChanged: onChanged,
        ),
        const Divider(height: 8, thickness: 0.5),
      ],
    );
  }
}
