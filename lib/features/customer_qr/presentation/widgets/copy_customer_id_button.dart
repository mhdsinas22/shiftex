import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';

/// Dark pill button used to copy the customer's membership ID to clipboard.
class CopyCustomerIdButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isEnabled;
  final double height;

  const CopyCustomerIdButton({
    super.key,
    required this.onPressed,
    this.isEnabled = true,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButtonDark,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.primaryButtonDark.withValues(
            alpha: 0.45,
          ),
          disabledForegroundColor: AppColors.white.withValues(alpha: 0.75),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const StadiumBorder(),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.copy_rounded, size: 18),
              SizedBox(width: 8),
              Text(
                'Copy ID',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
