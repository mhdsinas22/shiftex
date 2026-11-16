import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_strings.dart';
import 'package:shiftex/core/utils/validators.dart';

class PasswordRequirementIndicator extends StatelessWidget {
  final String password;

  const PasswordRequirementIndicator({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    final isSatisfied = Validators.isPasswordRuleSatisfied(password);

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color:
                isSatisfied
                    ? AppColors.validationSuccess
                    : AppColors.validationSuccess.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 11.5,
            color: AppColors.white,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            AppStrings.passwordRequirementText,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.w500,
              color:
                  isSatisfied
                      ? AppColors.validationSuccess
                      : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
