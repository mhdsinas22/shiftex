import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';

/// Primary CTA button opening the Monthly Statement selector & exporter sheet.
class MonthlyStatementButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isBusy;

  const MonthlyStatementButton({
    super.key,
    required this.onPressed,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isBusy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButtonDark,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.primaryButtonDisabled,
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              else
                const Icon(Icons.download_rounded, size: 19),
              const SizedBox(width: 8),
              const Text(
                'Download Monthly Statement (PDF / CSV)',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
