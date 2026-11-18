import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shiftex/core/constants/app_colors.dart';

/// Renders an ISO-compliant scannable QR code inside the nested rounded frame
/// with loading, expired/revoked, and refreshing overlays.
class CustomerQrCode extends StatelessWidget {
  final String? qrPayload;
  final double size;
  final bool isLoading;
  final bool isRefreshing;
  final bool isExpired;
  final VoidCallback? onRefreshTap;

  const CustomerQrCode({
    super.key,
    required this.qrPayload,
    required this.size,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isExpired = false,
    this.onRefreshTap,
  });

  @override
  Widget build(BuildContext context) {
    final outerSize = size.clamp(160.0, 290.0);
    final outerPadding = (outerSize * 0.085).clamp(12.0, 20.0);
    final innerPadding = (outerSize * 0.085).clamp(12.0, 20.0);
    final qrRenderSize = outerSize - (outerPadding * 2) - (innerPadding * 2);

    return Semantics(
      label: 'Personal accrual QR code',
      image: true,
      child: Container(
        width: outerSize,
        height: outerSize,
        padding: EdgeInsets.all(outerPadding),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Container(
          padding: EdgeInsets.all(innerPadding),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A101828),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isLoading && (qrPayload == null || qrPayload!.isEmpty))
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.primaryBlue,
                  ),
                )
              else if (qrPayload != null && qrPayload!.isNotEmpty)
                Opacity(
                  opacity: isExpired ? 0.22 : 1,
                  child: QrImageView(
                    data: qrPayload!,
                    version: QrVersions.auto,
                    size: qrRenderSize,
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0E1525),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0E1525),
                    ),
                  ),
                ),
              if (isRefreshing)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                )
              else if (isExpired)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'QR Pass Inactive',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.errorRed,
                        ),
                      ),
                    ),
                    if (onRefreshTap != null) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: onRefreshTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryButtonDark,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 36),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Refresh QR',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
