import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

/// Displays the 4 quick-select claim presets (100, 250, 500, 1,000 pts)
/// with INR conversions computed dynamically from the backend rate.
class ClaimAmountPresets extends StatelessWidget {
  final List<int> presets;
  final int selectedPoints;
  final int availablePoints;
  final double pointsToInrRate;
  final ValueChanged<int> onPresetSelected;

  const ClaimAmountPresets({
    super.key,
    this.presets = const [100, 250, 500, 1000],
    required this.selectedPoints,
    required this.availablePoints,
    required this.pointsToInrRate,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quick Presets',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Instant Points',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 0; i < presets.length; i++) ...[
              Expanded(
                child: _buildPresetTile(
                  context,
                  points: presets[i],
                ),
              ),
              if (i < presets.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPresetTile(BuildContext context, {required int points}) {
    final isSelected = selectedPoints == points;
    final isEnabled = availablePoints >= points;
    final ptsLabel = '${HomeFormatters.formatPoints(points)} pts';

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.45,
      child: Material(
        color:
            isSelected
                ? AppColors.primaryButtonDark
                : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEnabled ? () => onPresetSelected(points) : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isSelected
                        ? AppColors.primaryButtonDark
                        : AppColors.divider,
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  ptsLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color:
                        isSelected
                            ? AppColors.white
                            : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
