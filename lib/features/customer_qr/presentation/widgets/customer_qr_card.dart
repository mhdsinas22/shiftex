import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/customer_qr/domain/entities/customer_qr_entity.dart';
import 'package:shiftex/features/customer_qr/presentation/widgets/copy_customer_id_button.dart';
import 'package:shiftex/features/customer_qr/presentation/widgets/customer_qr_code.dart';

/// Primary card displaying the customer's accrual-only personal QR code,
/// membership identity, Copy ID and Done actions, and accrual security notice.
class CustomerQrCard extends StatelessWidget {
  final CustomerQrEntity? qrData;
  final bool isLoading;
  final bool isRefreshing;
  final bool isExpired;
  final String? errorMessage;
  final VoidCallback onCopyId;
  final VoidCallback onDone;
  final VoidCallback onRefresh;

  const CustomerQrCard({
    super.key,
    required this.qrData,
    required this.isLoading,
    required this.isRefreshing,
    required this.isExpired,
    required this.onCopyId,
    required this.onDone,
    required this.onRefresh,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        final horizontalPad = isCompact ? 16.0 : 22.0;
        final availableInnerWidth =
            (constraints.maxWidth - (horizontalPad * 2)).clamp(160.0, 420.0);
        final qrSize = (availableInnerWidth * 0.78).clamp(185.0, 260.0);
        final buttonHeight = isCompact ? 46.0 : 50.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            14,
            horizontalPad,
            isCompact ? 18 : 22,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppColors.dragHandle,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed:
                            (isLoading || isRefreshing) ? null : onRefresh,
                        tooltip: 'Refresh QR pass',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color:
                              (isLoading || isRefreshing)
                                  ? AppColors.textSecondary.withValues(
                                    alpha: 0.4,
                                  )
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add Points',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isCompact ? 22 : 25,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Present this QR code to the cashier to\ncredit points to your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isCompact ? 13 : 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              if (errorMessage != null && qrData == null)
                _buildErrorState(errorMessage!, qrSize)
              else
                CustomerQrCode(
                  qrPayload: qrData?.qrPayload,
                  size: qrSize,
                  isLoading: isLoading,
                  isRefreshing: isRefreshing,
                  isExpired: isExpired,
                  onRefreshTap: onRefresh,
                ),
              const SizedBox(height: 18),
              Text(
                qrData?.fullName ?? (isLoading ? 'Loading member...' : '—'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isCompact ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                qrData?.membershipId ?? (isLoading ? 'SHFT-••••' : 'Unavailable'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: CopyCustomerIdButton(
                      onPressed: onCopyId,
                      isEnabled:
                          qrData != null && qrData!.membershipId.isNotEmpty,
                      height: buttonHeight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: buttonHeight,
                      child: FilledButton(
                        onPressed: onDone,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.inputBackground,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: const StadiumBorder(),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Done',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, thickness: 1, color: AppColors.divider),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Accrual pass only • Cannot charge or deduct',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isCompact ? 11.5 : 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String message, double size) {
    final containerSize = size.clamp(160.0, 260.0);
    return Container(
      width: containerSize,
      height: containerSize,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.qr_code_2_rounded,
            size: 38,
            color: AppColors.errorRed,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.errorRed,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRefresh,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryButtonDark,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
              minimumSize: const Size(0, 38),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Retry',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
