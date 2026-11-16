import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_spacing.dart';
import 'package:shiftex/core/constants/app_strings.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';
import 'package:shiftex/core/widgets/encrypted_vault_footer.dart';

class ShiiftexAuthScaffold extends StatelessWidget {
  final Widget? topBar;
  final Widget? headerBadge;
  final String title;
  final String? subtitle;
  final Widget? customSubtitleWidget;
  final Widget sheetChild;
  final String footerText;
  final EdgeInsetsGeometry? sheetPadding;
  final bool lightTopGlow;

  const ShiiftexAuthScaffold({
    super.key,
    this.topBar,
    this.headerBadge,
    required this.title,
    this.subtitle,
    this.customSubtitleWidget,
    required this.sheetChild,
    this.footerText = AppStrings.encryptedVaultFooter,
    this.sheetPadding,
    this.lightTopGlow = true,
  });

  double _estimateHeaderHeight(ResponsiveLayout responsive) {
    double height = responsive.isShortScreen ? 26 : 38;
    if (topBar != null) {
      height += responsive.isShortScreen ? 50 : 58;
    }
    if (headerBadge != null) {
      height +=
          responsive.logoSize(defaultSize: 74) +
          (responsive.isShortScreen ? 10 : 16);
    }
    height += responsive.titleFontSize * 1.25;
    if (subtitle != null || customSubtitleWidget != null) {
      height += responsive.subtitleFontSize * 2.8 + 8;
    }
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final hPad = responsive.sheetHorizontalPadding;
    final resolvedSheetPadding =
        sheetPadding ??
        EdgeInsets.fromLTRB(
          hPad,
          responsive.isShortScreen ? 10 : 12,
          hPad,
          responsive.isShortScreen ? 10 : 16,
        );

    final topHeaderPad =
        topBar != null
            ? 8.0
            : (responsive.isKeyboardVisible
                ? 10.0
                : (responsive.isShortScreen
                    ? 14.0
                    : (responsive.isCompactScreen ? 18.0 : 24.0)));
    final bottomHeaderPad =
        responsive.isKeyboardVisible
            ? 12.0
            : (responsive.isShortScreen
                ? 14.0
                : (responsive.isCompactScreen ? 18.0 : 24.0));

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.gradientDeepBlue,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // Main Royal Blue background gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        lightTopGlow
                            ? const [
                              Color(0xFFEFF6FF),
                              Color(0xFF4BA0FA),
                              Color(0xFF0A66E2),
                              Color(0xFF0051C4),
                            ]
                            : const [
                              Color(0xFF2E8AF7),
                              Color(0xFF0B68E3),
                              Color(0xFF0051C4),
                            ],
                    stops:
                        lightTopGlow
                            ? const [0.0, 0.16, 0.34, 1.0]
                            : const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
            // Soft radial top-left light glow matching the screenshots
            if (lightTopGlow)
              Positioned(
                top: -80,
                left: -60,
                width: 320,
                height: 300,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.72),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Bottom white backdrop so bottom overscroll/safe area stays pure white
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: responsive.height * 0.42,
              child: const IgnorePointer(
                child: ColoredBox(color: AppColors.sheetBackground),
              ),
            ),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, viewportConstraints) {
                  final estimatedHeader = _estimateHeaderHeight(responsive);
                  final minSheetHeight = math.max(
                    0.0,
                    viewportConstraints.maxHeight - estimatedHeader,
                  );

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewportConstraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              hPad,
                              topHeaderPad,
                              hPad,
                              bottomHeaderPad,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: responsive.maxContentWidth,
                              ),
                              child: Column(
                                children: [
                                  if (topBar != null) ...[
                                    topBar!,
                                    SizedBox(
                                      height:
                                          responsive.isShortScreen ? 10 : 16,
                                    ),
                                  ],
                                  if (headerBadge != null &&
                                      (!responsive.isKeyboardVisible ||
                                          !responsive.isShortScreen)) ...[
                                    headerBadge!,
                                    SizedBox(
                                      height:
                                          responsive.isShortScreen ? 10 : 16,
                                    ),
                                  ],
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: responsive.titleFontSize,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textOnBlue,
                                      letterSpacing: -0.5,
                                      height: 1.18,
                                    ),
                                  ),
                                  if (customSubtitleWidget != null) ...[
                                    const SizedBox(height: 6),
                                    customSubtitleWidget!,
                                  ] else if (subtitle != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitle!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: responsive.subtitleFontSize,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textOnBlue.withValues(
                                          alpha: 0.88,
                                        ),
                                        height: 1.38,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            constraints: BoxConstraints(
                              minHeight: minSheetHeight,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.sheetBackground,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(
                                  AppSpacing.sheetTopRadius,
                                ),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Padding(
                                padding: resolvedSheetPadding,
                                child: Center(
                                  heightFactor: 1.0,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: responsive.maxContentWidth,
                                      minHeight: math.max(
                                        0.0,
                                        minSheetHeight -
                                            (responsive.isShortScreen
                                                ? 24.0
                                                : 32.0),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 5,
                                              margin: EdgeInsets.only(
                                                bottom:
                                                    responsive.isShortScreen
                                                        ? 12
                                                        : 18,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.dragHandle,
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                            sheetChild,
                                          ],
                                        ),
                                        EncryptedVaultFooter(text: footerText),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
