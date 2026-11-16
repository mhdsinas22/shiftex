import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/widgets/shiiftex_primary_button.dart';

class ShiiftexInfoBottomSheet extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;

  const ShiiftexInfoBottomSheet({
    super.key,
    required this.title,
    required this.message,
    this.buttonLabel = 'Close',
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Close',
  }) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      constraints: BoxConstraints(maxHeight: maxHeight),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ShiiftexInfoBottomSheet(
          title: title,
          message: message,
          buttonLabel: buttonLabel,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.dragHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ShiiftexPrimaryButton(
              label: buttonLabel,
              showTrailingArrow: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
