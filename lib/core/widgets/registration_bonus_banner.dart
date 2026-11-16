import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_strings.dart';

class RegistrationBonusBanner extends StatelessWidget {
  final String text;

  const RegistrationBonusBanner({
    super.key,
    this.text = AppStrings.bonusBannerText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.bonusBannerBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.bonusBannerBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🎉',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.bonusBannerText,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
