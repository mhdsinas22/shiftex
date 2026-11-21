import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

/// Expandable audit breakdown displayed for Claim Redemption entries.
class ClaimAuditDetails extends StatelessWidget {
  final ActivityTransactionEntity transaction;

  const ClaimAuditDetails({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final d = transaction.details;
    final pts =
        transaction.pointsDelta < 0
            ? transaction.pointsDelta.abs()
            : (d.requestedPoints ?? 0);
    final rateLabel =
        '${transaction.historicalPointsPerRupee} pts = ₹1.00 (₹${transaction.historicalRate.toStringAsFixed(2)}/pt)';
    final timestamp = HomeFormatters.formatUnlockDateTime(
      d.redeemedAt ?? transaction.createdAt,
    );

    final rows = <MapEntry<String, String>>[
      MapEntry(
        'Merchant / Store',
        d.merchantName?.isNotEmpty == true
            ? d.merchantName!
            : 'ShiftEx Partner Counter',
      ),
      if (d.terminalId != null && d.terminalId!.isNotEmpty)
        MapEntry('Terminal ID', d.terminalId!),
      MapEntry(
        'Claim Voucher Code',
        d.claimVoucherCode?.isNotEmpty == true
            ? d.claimVoucherCode!
            : transaction.referenceCode,
      ),
      MapEntry(
        'Reward Name',
        d.rewardName?.isNotEmpty == true ? d.rewardName! : transaction.title,
      ),
      if (d.orderReference != null && d.orderReference!.isNotEmpty)
        MapEntry('Order Reference', d.orderReference!),
      MapEntry(
        transaction.isFailedOrCancelledClaim
            ? 'Requested Points'
            : 'Points Deduction',
        transaction.isFailedOrCancelledClaim
            ? '${HomeFormatters.formatPoints(pts)} pts (Released)'
            : '-${HomeFormatters.formatPoints(pts)} pts',
      ),
      MapEntry('Applied Conversion Rate', rateLabel),
      MapEntry(
        'Historical Cash Value',
        HomeFormatters.formatInr(transaction.historicalInrValue),
      ),
      MapEntry('Timestamp', timestamp),
      MapEntry(
        'Verification Status',
        d.auditStatus?.isNotEmpty == true
            ? '${transaction.status} (${d.auditStatus})'
            : transaction.status,
      ),
      if (d.rejectedReason != null && d.rejectedReason!.isNotEmpty)
        MapEntry('Rejection Note', d.rejectedReason!),
      if (d.flaggedReason != null && d.flaggedReason!.isNotEmpty)
        MapEntry('Audit Note', d.flaggedReason!),
      MapEntry(
        'Audit Reference',
        d.auditReference?.isNotEmpty == true
            ? d.auditReference!
            : transaction.referenceCode,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Claim Audit Details',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    rows[i].key,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Text(
                    rows[i].value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
