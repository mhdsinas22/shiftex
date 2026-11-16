import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_strings.dart';

class EncryptedVaultFooter extends StatelessWidget {
  final String text;

  const EncryptedVaultFooter({
    super.key,
    this.text = AppStrings.encryptedVaultFooter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 15,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
