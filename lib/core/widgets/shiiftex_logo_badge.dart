import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_assets.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';

enum ShiiftexLogoVariant {
  full,
  markOnly,
  keyIcon,
}

class ShiiftexLogoBadge extends StatelessWidget {
  final ShiiftexLogoVariant variant;
  final double size;

  const ShiiftexLogoBadge({
    super.key,
    this.variant = ShiiftexLogoVariant.full,
    this.size = 74,
  });

  @override
  Widget build(BuildContext context) {
    final adaptiveSize = ResponsiveLayout.of(
      context,
    ).logoSize(defaultSize: size);

    return Container(
      width: adaptiveSize,
      height: adaptiveSize,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(adaptiveSize * 0.31),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(
        variant == ShiiftexLogoVariant.full
            ? adaptiveSize * 0.135
            : adaptiveSize * 0.2,
      ),
      child: _buildContent(adaptiveSize),
    );
  }

  Widget _buildContent(double adaptiveSize) {
    switch (variant) {
      case ShiiftexLogoVariant.full:
        return ClipRRect(
          borderRadius: BorderRadius.circular(adaptiveSize * 0.16),
          child: Image.asset(
            AppAssets.splashlogpng,
            fit: BoxFit.contain,
          ),
        );
      case ShiiftexLogoVariant.markOnly:
        return ClipRect(
          child: Align(
            alignment: const Alignment(0, -0.42),
            heightFactor: 0.56,
            child: Image.asset(
              AppAssets.splashlogpng,
              fit: BoxFit.cover,
            ),
          ),
        );
      case ShiiftexLogoVariant.keyIcon:
        return Center(
          child: Icon(
            Icons.vpn_key_rounded,
            color: AppColors.resetKeyOrange,
            size: adaptiveSize * 0.46,
          ),
        );
    }
  }
}
