import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/advertisements/domain/entities/advertisement_entity.dart';
import 'package:shiftex/features/advertisements/presentation/widgets/advertisement_countdown.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

/// Centered promotional popup card with a frosted backdrop, top campaign pill
/// + circular `Xs` countdown header, full-bleed rounded poster artwork, and an
/// optional soft-grey campaign details card when offer metadata or CTA exists.
class AdvertisementPopup extends StatelessWidget {
  final AdvertisementEntity advertisement;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback onClose;
  final VoidCallback? onCtaTap;

  const AdvertisementPopup({
    super.key,
    required this.advertisement,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onClose,
    this.onCtaTap,
  });

  String _formatValidityWithRemaining(AdvertisementEntity ad) {
    final range = HomeFormatters.formatShortDateRange(ad.startAt, ad.endAt);
    final ref = (ad.serverNow ?? DateTime.now()).toLocal();
    final endLocal = ad.endAt.toLocal();
    final refDay = DateTime(ref.year, ref.month, ref.day);
    final endDay = DateTime(endLocal.year, endLocal.month, endLocal.day);
    final daysLeft = endDay.difference(refDay).inDays;

    if (daysLeft > 1) {
      return '$range ($daysLeft Days Left)';
    }
    if (daysLeft == 1) {
      return '$range (1 Day Left)';
    }
    if (daysLeft == 0) {
      return '$range (Ends Today)';
    }
    return range;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompactWidth = screenSize.width < 360;
    final horizontalInset = isCompactWidth ? 16.0 : 24.0;
    final cardWidth = math.min(screenSize.width - (horizontalInset * 2), 380.0);
    final maxCardHeight = screenSize.height * 0.88;
    final cardPadding = isCompactWidth ? 14.0 : 16.0;

    final validImageUrl = advertisement.validatedImageUrl;
    final descriptionText = advertisement.offerDetails.trim();
    final hasCta = advertisement.hasConfiguredCta && onCtaTap != null;
    final showDetailsBox = descriptionText.isNotEmpty || hasCta;
    final validityText = _formatValidityWithRemaining(advertisement);

    final innerContentWidth = cardWidth - (cardPadding * 2);
    final maxBannerHeight = showDetailsBox
        ? math.min(math.max(screenSize.height * 0.34, 180.0), 300.0)
        : math.min(math.max(screenSize.height * 0.44, 210.0), 380.0);
    final preferredBannerHeight = showDetailsBox
        ? innerContentWidth * 0.96
        : innerContentWidth * 1.06;
    final bannerHeight = math.min(preferredBannerHeight, maxBannerHeight);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          onClose();
        }
      },
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Promotional advertisement popup',
        child: Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: const ColoredBox(color: Color(0x9E4B5563)),
                ),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cardWidth,
                      maxHeight: maxCardHeight,
                    ),
                    child: Container(
                      key: const ValueKey('advertisement_popup_card'),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 32,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.all(cardPadding),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PopupHeaderRow(
                                title: advertisement.title.trim(),
                                remainingSeconds: remainingSeconds,
                                totalSeconds: totalSeconds,
                                onClose: onClose,
                                compact: isCompactWidth,
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: SizedBox(
                                  height: bannerHeight,
                                  child: validImageUrl != null
                                      ? Image.network(
                                          validImageUrl,
                                          fit: BoxFit.cover,
                                          loadingBuilder:
                                              (
                                                context,
                                                child,
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return const _AdBannerFallback();
                                              },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return const _AdBannerFallback();
                                              },
                                        )
                                      : const _AdBannerFallback(),
                                ),
                              ),
                              if (showDetailsBox) ...[
                                const SizedBox(height: 14),
                                _CampaignDetailsCard(
                                  offerDetails: descriptionText,
                                  validityText: validityText,
                                  ctaLabel: hasCta
                                      ? advertisement.ctaLabel!.trim()
                                      : null,
                                  ctaActionType: advertisement.ctaActionType,
                                  onCtaTap: onCtaTap,
                                  compact: isCompactWidth,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupHeaderRow extends StatelessWidget {
  final String title;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback onClose;
  final bool compact;

  const _PopupHeaderRow({
    required this.title,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onClose,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Container(
            key: const ValueKey('advertisement_campaign_pill'),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF1EDFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: Color(0xFF5B21B6),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title.isEmpty ? 'Campaign Offer' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11.5 : 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4C1D95),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(flex: 5),
        Row(
          children: [
            AdvertisementCountdown(
              remainingSeconds: remainingSeconds,
              totalSeconds: totalSeconds,
            ),
            if (remainingSeconds <= 0) ...[
              _SubtleCloseButton(onClose: onClose),
            ],
          ],
        ),
      ],
    );
  }
}

class _SubtleCloseButton extends StatelessWidget {
  final VoidCallback onClose;

  const _SubtleCloseButton({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close advertisement',
      child: Material(
        color: AppColors.inputBackground,
        shape: const CircleBorder(),
        child: InkWell(
          key: const ValueKey('advertisement_close_button'),
          customBorder: const CircleBorder(),
          onTap: onClose,
          child: const SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: Color(0xFF475467),
            ),
          ),
        ),
      ),
    );
  }
}

class _CampaignDetailsCard extends StatelessWidget {
  final String offerDetails;
  final String validityText;
  final String? ctaLabel;
  final AdvertisementCtaActionType? ctaActionType;
  final VoidCallback? onCtaTap;
  final bool compact;

  const _CampaignDetailsCard({
    required this.offerDetails,
    required this.validityText,
    this.ctaLabel,
    this.ctaActionType,
    this.onCtaTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (offerDetails.isNotEmpty) {
      rows.add(
        _DetailInfoRow(
          icon: Icons.savings_rounded,
          iconColor: AppColors.primaryBlue,
          title: 'Promotional Offer',
          subtitle: offerDetails,
          compact: compact,
        ),
      );
    }

    if (rows.isNotEmpty) {
      rows.add(const _DetailsDivider());
    }

    rows.add(
      _DetailInfoRow(
        icon: Icons.calendar_today_rounded,
        iconColor: const Color(0xFFF04438),
        title: 'Validity Window',
        subtitle: validityText,
        compact: compact,
      ),
    );

    if (ctaLabel != null && ctaLabel!.isNotEmpty && onCtaTap != null) {
      rows.add(const _DetailsDivider());
      rows.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('advertisement_cta_button'),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            onTap: onCtaTap,
            child: _DetailInfoRow(
              icon: ctaActionType == AdvertisementCtaActionType.externalUrl
                  ? Icons.open_in_new_rounded
                  : Icons.qr_code_2_rounded,
              iconColor: AppColors.textPrimary,
              title: ctaLabel!,
              subtitle: ctaActionType == AdvertisementCtaActionType.externalUrl
                  ? 'Tap to explore campaign offer'
                  : 'Tap to continue in app',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              compact: compact,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

class _DetailsDivider extends StatelessWidget {
  const _DetailsDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFEAECF0)),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool compact;

  const _DetailInfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 11 : 13,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEAECF0), width: 0.9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 13 : 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

class _AdBannerFallback extends StatelessWidget {
  const _AdBannerFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gradientDeepBlue,
            AppColors.primaryBlue,
            AppColors.gradientMidSky,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          size: 52,
          color: AppColors.white,
        ),
      ),
    );
  }
}
