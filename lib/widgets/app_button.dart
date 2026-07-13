import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isSecondary;
  final bool isLoading;
  final Color? customColor;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isSecondary = false,
    this.isLoading = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = customColor ??
        (isSecondary ? AppColors.primaryLight : AppColors.primaryGreen);
    final Color textColor = isSecondary ? AppColors.primaryGreen : AppColors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(16),
            border: isSecondary 
                ? Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3), width: 1.5)
                : null,
            boxShadow: isSecondary 
                ? null 
                : [
                    const BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: textColor, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
