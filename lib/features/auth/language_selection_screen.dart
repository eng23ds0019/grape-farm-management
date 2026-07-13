import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/l10n.dart';
import '../../shared/widgets/premium_background.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key, required this.onSelected});

  final Future<void> Function(String code) onSelected;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selected = 'en';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.grapeGreen,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.language,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 20),
         























                                : const Color(0xFFE5EADD),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selected == language.code
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: AppColors.grapeGreen,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    language.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(language.voiceLabel),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => widget.onSelected(_selected),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(AppStrings.of(context, 'continue')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
