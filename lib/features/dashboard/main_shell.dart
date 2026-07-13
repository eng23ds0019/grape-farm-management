import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/app_scope.dart';
import '../../core/app_theme.dart';
import '../../core/l10n.dart';
import '../../data/models/bill_record.dart';
import '../../data/models/diary_entry.dart';
import '../../data/models/expense_item.dart';
import '../../data/models/farm.dart';
import '../../data/models/farmer_profile.dart';
import '../../data/models/report_summary.dart';
import '../../data/services/ai_advisor_service.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/farm_repository.dart';
import '../../data/services/media_service.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/speech_service.dart';
import '../../shared/widgets/action_card.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/premium_background.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_card.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.profile,
    required this.farm,
    required this.repository,
    required this.auth,
    required this.analytics,
    required this.media,
    required this.ocr,
    required this.speech,
    required 










































































































































































































































































































































































































































































































































































































































































































































                padding: const EdgeInsets.all(18),
                children: [
                  SectionHeader(
                    title: AppStrings.of(context, 'history'),
                    subtitle: '${entries.length} AI-ready records',
                  ),
                  ...entries.map(
                    (entry) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.leafLight,
                          child: Icon(Icons.spa, color: AppColors.grapeGreen),
                        ),
                        title: Text('${entry.cropStage} • ${entry.workType}'),
                        subtitle: Text(
                          entry.cleanedText.isEmpty
                              ? DateFormat.yMMMd().format(entry.date)
                              : entry.cleanedText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          'Rs ${entry.totalExpense.toStringAsFixed(0)}',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({
    super.key,
    required this.profile,
    required this.farm,
    required this.repository,
  });

  final FarmerProfile profile;
  final Farm farm;
  final FarmRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: StreamBuilder<List<DiaryEntry>>(
            stream: repository.diaryStream(profile.farmerId, farm.farmId),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const <DiaryEntry>[];
              final breakdown = _categoryBreakdown(entries);
              final total = breakdown.values.fold<double>(
                0,
                (sum, value) => sum + value,
              );
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  SectionHeader(
                    title: AppStrings.of(context, 'analytics'),
                    subtitle: 'Power BI style, simplified for farmers',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Total',
                          value: 'Rs ${total.toStringAsFixed(0)}',
                          icon: Icons.currency_rupee,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
       



















































































































































































































































































































































































































































































































































































































































































































































                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                opacity: 0.78,
                child: Column(
                  children: [
                    TextField(
                      controller: _question,
                      minLines: 4,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: AppStrings.of(context, 'aiPlaceholder'),
                        prefixIcon: const Icon(Icons.edit_note),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
          child: SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _lineSpots(entries),
                    isCurved: true,
                    curveMode: CurveMode.natural,
                    color: AppColors.grapeGreen,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.grapeGreen.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _answer,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white.withValues(alpha: 0.78),
      side: BorderSide(color: AppColors.grapeGreen.withValues(alpha: 0.22)),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.profile, required this.auth});

  final FarmerProfile profile;
  final AuthServ







            padding: const EdgeInsets.all(18),
            children: [
              SectionHeader(
                title: AppStrings.of(context, 'settings'),
                subtitle: profile.phone,
              ),
              StatCard(
                label: AppStrings.of(context, 'profile'),
                value: profile.name,
                icon: Icons.person,
              ),
              const SizedBox(height: 12),
              StatCard(
                label: AppStrings.of(context, 'notifications'),
                value: 'Rain alerts, reminders, advisory FCM ready',
                icon: Icons.notifications_active,
                color: AppColors.softYellow,
              ),
              const SizedBox(height: 12),
              StatCard(
                label: 'Admin analytics',
                value: 'Signup, active users, crashes, photos, bills',
                icon: Icons.admin_panel_settings,
                color: AppColors.grapePurple,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => AppScope.of(context).setLanguage(''),
                icon: const Icon(Icons.language),
                label: const Text('Change language'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: auth.signOut,
                icon: const Icon(Icons.logout),
                label: Text(AppStrings.of(context, 'logout')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
