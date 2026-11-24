import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/features/change_password/presentation/bloc/change_password_state.dart';

/// Displays an animated 4-segment strength bar and real-time 5-rule checklist
/// derived from [ChangePasswordFormData].
class PasswordStrengthMeter extends StatelessWidget {
  final ChangePasswordFormData form;

  const PasswordStrengthMeter({super.key, required this.form});

  @override
  Widget build(BuildContext context) {
    final config = _strengthVisuals(form.strength);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Password Strength',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: config.badgeBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  config.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: config.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(4, (index) {
              final active = index < config.filledBars;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 3 ? 6 : 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 5,
                    decoration: BoxDecoration(
                      color: active ? config.accentColor : AppColors.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          _RequirementItem(
            label: 'At least 8 characters',
            met: form.hasMinLength,
          ),
          const SizedBox(height: 6),
          _RequirementItem(
            label: 'At least 1 uppercase letter (A-Z)',
            met: form.hasUppercase,
          ),
          const SizedBox(height: 6),
          _RequirementItem(
            label: 'At least 1 lowercase letter (a-z)',
            met: form.hasLowercase,
          ),
          const SizedBox(height: 6),
          _RequirementItem(
            label: 'At least 1 number (0-9)',
            met: form.hasNumber,
          ),
          const SizedBox(height: 6),
          _RequirementItem(
            label: 'At least 1 special character (!@#...)',
            met: form.hasSpecialChar,
          ),
          if (!form.isDifferentFromCurrent) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.errorBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.errorRed,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Must be different from your current password',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  _StrengthVisualConfig _strengthVisuals(PasswordStrengthLevel level) {
    switch (level) {
      case PasswordStrengthLevel.empty:
        return const _StrengthVisualConfig(
          label: 'Not set',
          filledBars: 0,
          accentColor: AppColors.textTertiary,
          badgeBackground: AppColors.cardSurface,
        );
      case PasswordStrengthLevel.weak:
        return const _StrengthVisualConfig(
          label: 'Weak',
          filledBars: 1,
          accentColor: AppColors.errorRed,
          badgeBackground: AppColors.errorSurface,
        );
      case PasswordStrengthLevel.fair:
        return const _StrengthVisualConfig(
          label: 'Fair',
          filledBars: 2,
          accentColor: AppColors.suspendedBadgeText,
          badgeBackground: AppColors.suspendedBadgeBg,
        );
      case PasswordStrengthLevel.good:
        return const _StrengthVisualConfig(
          label: 'Good',
          filledBars: 3,
          accentColor: AppColors.primaryBlue,
          badgeBackground: Color(0xFFEAF2FF),
        );
      case PasswordStrengthLevel.strong:
        return const _StrengthVisualConfig(
          label: 'Strong',
          filledBars: 4,
          accentColor: AppColors.approvedBadgeText,
          badgeBackground: AppColors.approvedBadgeBg,
        );
    }
  }
}

class _StrengthVisualConfig {
  final String label;
  final int filledBars;
  final Color accentColor;
  final Color badgeBackground;

  const _StrengthVisualConfig({
    required this.label,
    required this.filledBars,
    required this.accentColor,
    required this.badgeBackground,
  });
}

class _RequirementItem extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementItem({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: met ? AppColors.approvedBadgeBg : AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: met ? AppColors.approvedBadgeText : AppColors.textTertiary,
              width: 1.3,
            ),
          ),
          child: Icon(
            met ? Icons.check_rounded : Icons.circle,
            size: met ? 12 : 5,
            color: met ? AppColors.approvedBadgeText : AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
              color: met ? AppColors.approvedBadgeText : AppColors.textSecondary,
            ),
            child: Text(label),
          ),
        ),
      ],
    );
  }
}
