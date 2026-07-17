import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n.dart';
import '../../data/models/farmer_profile.dart';
import '../../data/services/farm_repository.dart';
import '../../shared/widgets/premium_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final User user;
  final FarmRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _village = TextEditingController();
  bool _consent = true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _village.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final language = AppScope.of(context).languageCode;
    await widget.repository.saveProfile(
      FarmerProfile(
        farmerId: widget.user.uid,
        name: _name.text.trim(),
        phone: widget.user.phoneNumber ?? '',
        village: _village.text.trim(),
        preferredLanguage: language,
        aiTrainingConsent: _consent,
      ),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                AppStrings.of(context, 'profile'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person),
                  hintText: AppStrings.of(context, 'name'),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _village,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.location_city),
                  hintText: AppStrings.of(context, 'village'),
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                value: _consent,
                onChanged: (value) => setState(() => _consent = value),
                title: const Text(
                  'Use my confirmed records for future farm AI',
                ),
                subtitle: const Text(
                  'Only your own farm data will be used for your advisor.',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(AppStrings.of(context, 'saveProfile')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
