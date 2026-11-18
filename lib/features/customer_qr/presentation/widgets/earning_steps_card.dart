import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';

/// Displays the 3-step guide explaining how points are earned at checkout.
class EarningStepsCard extends StatelessWidget {
  const EarningStepsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        final horizontalPad = isCompact ? 16.0 : 20.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            20,
            horizontalPad,
            20,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D101828),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      'How Earning Works',
                      style: TextStyle(
                        fontSize: isCompact ? 17 : 18.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '3 simple steps',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStepTile(
                badge: _buildStepBadge(
                  backgroundColor: const Color(0xFF0B1220),
                  child: const Text(
                    '1',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: 'Present Pass at Checkout',
                subtitle: 'Show this QR to the cashier before payment.',
              ),
              const SizedBox(height: 10),
              _buildStepTile(
                badge: _buildStepBadge(
                  backgroundColor: AppColors.primaryBlue,
                  child: const Text(
                    '2',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: 'Cashier Scans & Enters Bill',
                subtitle: 'The POS registers your account and assigns points.',
              ),
              const SizedBox(height: 10),
              _buildStepTile(
                badge: _buildStepBadge(
                  backgroundColor: const Color(0xFF9DF847),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: Color(0xFF0E1525),
                  ),
                ),
                title: 'Instant Account Credit',
                subtitle:
                    "Points arrive in your available or future balance according to the Admin's allocation rules.",
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepBadge({
    required Color backgroundColor,
    required Widget child,
  }) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }

  Widget _buildStepTile({
    required Widget badge,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          badge,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
