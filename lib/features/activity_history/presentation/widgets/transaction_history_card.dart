import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/activity_history/presentation/widgets/claim_audit_details.dart';
import 'package:shiftex/features/activity_history/presentation/widgets/locked_points_details.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

/// Individual white rounded transaction card supporting colored indicators,
/// split available/locked badges, historical INR display, and on-demand expansion.
class TransactionHistoryCard extends StatelessWidget {
  final ActivityTransactionEntity transaction;
  final bool isExpanded;
  final bool isLoadingDetail;
  final VoidCallback onToggleExpand;

  const TransactionHistoryCard({
    super.key,
    required this.transaction,
    required this.isExpanded,
    required this.isLoadingDetail,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _resolveVisuals(transaction);
    final timeStr = _formatLocalTime(transaction.createdAt);
    final pointsText = _formatSignedPoints(transaction);
    final inrText = _formatHistoricalInr(transaction);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: transaction.isExpandable ? onToggleExpand : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  isExpanded
                      ? AppColors.primaryBlue.withValues(alpha: 0.25)
                      : AppColors.divider.withValues(alpha: 0.7),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06101828),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: visual.iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      visual.icon,
                      size: 20,
                      color: visual.iconColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (transaction.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            transaction.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildStatusPill(transaction.status),
                            Text(
                              '$timeStr • ${transaction.referenceCode}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (transaction.lockedPointsPart > 0 ||
                            (transaction.availablePointsPart > 0 &&
                                transaction.kind == ActivityKind.posPurchase)) ...[
                          const SizedBox(height: 7),
                          _buildSplitBadges(transaction),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pointsText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: visual.pointsColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inrText,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (transaction.isExpandable) ...[
                        const SizedBox(height: 6),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                if (isLoadingDetail)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.primaryBlue,
                      backgroundColor: AppColors.inputBackground,
                    ),
                  ),
                _buildExpandedDetails(transaction),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplitBadges(ActivityTransactionEntity tx) {
    final avail = tx.availablePointsPart;
    final locked = tx.lockedPointsPart;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (locked > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.pendingBadgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${HomeFormatters.formatPoints(locked)} pts Locked',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.pendingBadgeText,
              ),
            ),
          ),
        if (avail > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.approvedBadgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${HomeFormatters.formatPoints(avail)} pts Available',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.approvedBadgeText,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusPill(String status) {
    final lower = status.toLowerCase();
    final Color bg;
    final Color fg;

    if (lower == 'completed' || lower == 'unlocked' || lower == 'released') {
      bg = AppColors.approvedBadgeBg;
      fg = AppColors.approvedBadgeText;
    } else if (lower.contains('locked') ||
        lower.contains('progress') ||
        lower == 'pending') {
      bg = AppColors.pendingBadgeBg;
      fg = AppColors.pendingBadgeText;
    } else if (lower == 'rejected' ||
        lower == 'forfeited' ||
        lower == 'flagged') {
      bg = AppColors.rejectedBadgeBg;
      fg = AppColors.rejectedBadgeText;
    } else {
      bg = AppColors.inputBackground;
      fg = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildExpandedDetails(ActivityTransactionEntity tx) {
    switch (tx.kind) {
      case ActivityKind.claimRedemption:
        return ClaimAuditDetails(transaction: tx);
      case ActivityKind.posPurchase:
      case ActivityKind.lockedRelease:
        return LockedPointsDetails(transaction: tx);
      case ActivityKind.dailyStreak:
        final d = tx.details;
        return _buildGenericDetailsCard(
          heading: 'Daily Streak Details',
          rows: [
            if (d.streakDay != null)
              MapEntry('Streak Day', 'Day ${d.streakDay} of 7'),
            MapEntry(
              'Points Awarded',
              '+${HomeFormatters.formatPoints(tx.pointsDelta)} pts',
            ),
            if (d.cycleReference != null && d.cycleReference!.isNotEmpty)
              MapEntry('Cycle Reference', d.cycleReference!),
            MapEntry(
              'Credited Timestamp',
              HomeFormatters.formatUnlockDateTime(tx.createdAt),
            ),
            if (d.unlockAt != null)
              MapEntry(
                'Unlock Schedule',
                HomeFormatters.formatUnlockDateTime(d.unlockAt!),
              ),
            MapEntry(
              'Streak Status',
              d.inProgressStreak ? 'In Progress (Locks on Day 7)' : tx.status,
            ),
          ],
        );
      case ActivityKind.festivalBonus:
        final d = tx.details;
        return _buildGenericDetailsCard(
          heading: 'Festival Bonus Details',
          rows: [
            MapEntry('Campaign Name', d.campaignName ?? tx.title),
            if (d.campaignCode != null && d.campaignCode!.isNotEmpty)
              MapEntry('Campaign Code', d.campaignCode!),
            MapEntry(
              'Bonus Points',
              '+${HomeFormatters.formatPoints(tx.pointsDelta)} pts',
            ),
            if (d.campaignValidity != null && d.campaignValidity!.isNotEmpty)
              MapEntry('Campaign Validity', d.campaignValidity!),
            MapEntry('Transaction Status', tx.status),
          ],
        );
      case ActivityKind.registrationBonus:
      case ActivityKind.adminAdjustment:
        final d = tx.details;
        return _buildGenericDetailsCard(
          heading:
              tx.kind == ActivityKind.registrationBonus
                  ? 'Registration Bonus Details'
                  : 'Authorized Adjustment Details',
          rows: [
            MapEntry(
              'Reason',
              d.adjustmentReason?.isNotEmpty == true
                  ? d.adjustmentReason!
                  : (tx.description.isNotEmpty ? tx.description : tx.title),
            ),
            MapEntry(
              'Timestamp',
              HomeFormatters.formatUnlockDateTime(tx.createdAt),
            ),
            MapEntry('Historical Value', _formatHistoricalInr(tx)),
            MapEntry('Status', tx.status),
          ],
        );
    }
  }

  Widget _buildGenericDetailsCard({
    required String heading,
    required List<MapEntry<String, String>> rows,
  }) {
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
          Text(
            heading,
            style: const TextStyle(
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

  String _formatSignedPoints(ActivityTransactionEntity tx) {
    if (tx.isFailedOrCancelledClaim) {
      return '0 pts';
    }
    if (tx.isReleaseEvent) {
      return '${HomeFormatters.formatPoints(tx.pointsDelta.abs())} pts';
    }
    final prefix = tx.pointsDelta > 0 ? '+' : '';
    return '$prefix${HomeFormatters.formatPoints(tx.pointsDelta)} pts';
  }

  String _formatHistoricalInr(ActivityTransactionEntity tx) {
    if (tx.isFailedOrCancelledClaim) {
      return '${HomeFormatters.formatInr(tx.historicalInrValue)} void';
    }
    if (tx.isDebit) {
      return '-${HomeFormatters.formatInr(tx.historicalInrValue)}';
    }
    return HomeFormatters.formatInr(tx.historicalInrValue);
  }

  String _formatLocalTime(DateTime utcDate) {
    final local = utcDate.toLocal();
    final hour12 =
        local.hour == 0
            ? 12
            : (local.hour > 12 ? local.hour - 12 : local.hour);
    final min = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$min $period';
  }

  _TransactionVisuals _resolveVisuals(ActivityTransactionEntity tx) {
    if (tx.isFailedOrCancelledClaim) {
      return const _TransactionVisuals(
        icon: Icons.cancel_outlined,
        iconColor: AppColors.rejectedBadgeText,
        iconBg: AppColors.rejectedBadgeBg,
        pointsColor: AppColors.rejectedBadgeText,
      );
    }

    switch (tx.kind) {
      case ActivityKind.posPurchase:
        return const _TransactionVisuals(
          icon: Icons.storefront_rounded,
          iconColor: AppColors.primaryBlue,
          iconBg: Color(0xFFEAF2FF),
          pointsColor: Color(0xFF15803D),
        );
      case ActivityKind.claimRedemption:
        return const _TransactionVisuals(
          icon: Icons.confirmation_number_outlined,
          iconColor: AppColors.textPrimary,
          iconBg: Color(0xFFF1F5F9),
          pointsColor: AppColors.textPrimary,
        );
      case ActivityKind.dailyStreak:
        return const _TransactionVisuals(
          icon: Icons.bolt_rounded,
          iconColor: Color(0xFF6D28D9),
          iconBg: Color(0xFFF3E8FF),
          pointsColor: Color(0xFF15803D),
        );
      case ActivityKind.festivalBonus:
        return const _TransactionVisuals(
          icon: Icons.celebration_rounded,
          iconColor: Color(0xFFD97706),
          iconBg: Color(0xFFFEF3C7),
          pointsColor: Color(0xFF15803D),
        );
      case ActivityKind.registrationBonus:
        return const _TransactionVisuals(
          icon: Icons.card_giftcard_rounded,
          iconColor: Color(0xFF047857),
          iconBg: Color(0xFFD1FAE5),
          pointsColor: Color(0xFF15803D),
        );
      case ActivityKind.lockedRelease:
        return const _TransactionVisuals(
          icon: Icons.lock_open_rounded,
          iconColor: AppColors.approvedBadgeText,
          iconBg: AppColors.approvedBadgeBg,
          pointsColor: AppColors.primaryBlue,
        );
      case ActivityKind.adminAdjustment:
        return _TransactionVisuals(
          icon: Icons.tune_rounded,
          iconColor: AppColors.textPrimary,
          iconBg: const Color(0xFFF1F5F9),
          pointsColor:
              tx.isCredit ? const Color(0xFF15803D) : AppColors.textPrimary,
        );
    }
  }
}

class _TransactionVisuals {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color pointsColor;

  const _TransactionVisuals({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.pointsColor,
  });
}
