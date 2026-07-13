import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../data/models/farm.dart';
import '../../data/services/farm_repository.dart';
import '../../shared/widgets/premium_background.dart';

class FarmProfileScreen extends StatefulWidget {
  const FarmProfileScreen({
    super.key,
    required this.farmerId,
    required this.repository,
  });

  final String farmerId;
  final FarmRepository repository;

  @override
  State<FarmProfileScreen> createState() => _FarmProfileScreenState();
}

class _FarmProfileScreenState extends State<FarmProfileScreen> {
  final _farmName = TextEditingController();
  final _acres = TextEditingController();
  final _location = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _farmName.dispose();
    _acres.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.repository.saveFarm(
      widget.farmerId,
      Farm(
        farmId: '',
        farmName: _farmName.text.trim(),
        crop: 'Grapes',
        acres: double.tryParse(_acres.text.trim()) ?? 0,
        location: _location.text.trim(),
      ),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                AppStrings.of(context, 'farmProfile'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _farmName,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.yard),
                  hintText: AppStrings.of(context, 'farmName'),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _acres,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.square_foot),
                  hintText: AppStrings.of(context, 'acres'),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _location,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.place),
                  hintText: AppStrings.of(context, 'location'),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(AppStrings.of(context, 'saveFarm')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
