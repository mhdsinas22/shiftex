import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_spacing.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';

class ShiiftexPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool showTrailingArrow;

  const ShiiftexPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.showTrailingArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = ResponsiveLayout.of(context).buttonHeight;

    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButtonDark,
          disabledBackgroundColor:
              AppColors.primaryButtonDark.withValues(alpha: 0.65),
          foregroundColor: AppColors.white,
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
        child:
            isLoading
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(leadingIcon, size: 19, color: AppColors.white),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailingIcon, size: 19, color: AppColors.white),
                    ] else if (showTrailingArrow && leadingIcon == null) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                        color: AppColors.white,
                      ),
                    ],
                  ],
                ),
      ),
    );
  }
}
