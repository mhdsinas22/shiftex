import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_spacing.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';

class ShiiftexOtpInput extends StatefulWidget {
  final String code;
  final ValueChanged<String> onChanged;
  final int length;
  final bool hasError;

  const ShiiftexOtpInput({
    super.key,
    required this.code,
    required this.onChanged,
    this.length = 6,
    this.hasError = false,
  });

  @override
  State<ShiiftexOtpInput> createState() => _ShiiftexOtpInputState();
}

class _ShiiftexOtpInputState extends State<ShiiftexOtpInput> {
  late final FocusNode _hiddenFocusNode;
  late final TextEditingController _hiddenController;

  @override
  void initState() {
    super.initState();
    _hiddenFocusNode = FocusNode();
    _hiddenController = TextEditingController(text: widget.code);
  }

  @override
  void didUpdateWidget(covariant ShiiftexOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.code != _hiddenController.text) {
      _hiddenController.value = TextEditingValue(
        text: widget.code,
        selection: TextSelection.collapsed(offset: widget.code.length),
      );
    }
  }

  @override
  void dispose() {
    _hiddenFocusNode.dispose();
    _hiddenController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty) {
      final clipped =
          digits.length > widget.length
              ? digits.substring(0, widget.length)
              : digits;
      widget.onChanged(clipped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final activeIndex =
        widget.code.length < widget.length
            ? widget.code.length
            : widget.length - 1;

    return Semantics(
      label: '6-digit verification code input',
      value: '${widget.code.length} of ${widget.length} digits entered',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _hiddenFocusNode.requestFocus(),
        onLongPress: _pasteFromClipboard,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Hidden text field to support hardware keyboard and paste actions
            SizedBox(
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0,
                child: TextField(
                  focusNode: _hiddenFocusNode,
                  controller: _hiddenController,
                  keyboardType: TextInputType.none,
                  maxLength: widget.length,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  onChanged: widget.onChanged,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth =
                    constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : responsive.width -
                            (responsive.sheetHorizontalPadding * 2);
                final spacing =
                    availableWidth < 310
                        ? 4.0
                        : (availableWidth < 350 ? 6.0 : 9.0);
                final rawBoxWidth =
                    (availableWidth - (spacing * (widget.length - 1))) /
                    widget.length;
                final boxWidth = math.min(52.0, math.max(28.0, rawBoxWidth));
                final heightRatio = responsive.isShortScreen ? 1.15 : 1.24;
                final boxHeight = (boxWidth * heightRatio).clamp(44.0, 64.0);
                final digitFontSize = boxWidth < 40 ? 18.0 : 21.0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.length, (index) {
                    final hasChar = index < widget.code.length;
                    final char = hasChar ? widget.code[index] : '';
                    final isCurrentBox =
                        index == activeIndex &&
                        widget.code.length < widget.length;

                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == widget.length - 1 ? 0 : spacing,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: boxWidth,
                        height: boxHeight,
                        decoration: BoxDecoration(
                          color:
                              isCurrentBox
                                  ? AppColors.white
                                  : AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(
                            math.min(AppSpacing.otpBoxRadius, boxWidth * 0.44),
                          ),
                          border: Border.all(
                            color:
                                widget.hasError
                                    ? AppColors.errorRed
                                    : (isCurrentBox
                                        ? AppColors.textPrimary
                                        : Colors.transparent),
                            width: isCurrentBox || widget.hasError ? 1.8 : 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child:
                            hasChar
                                ? Text(
                                  char,
                                  style: TextStyle(
                                    fontSize: digitFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                )
                                : isCurrentBox
                                ? Container(
                                  width: 1.8,
                                  height: boxHeight * 0.38,
                                  decoration: BoxDecoration(
                                    color: AppColors.textPrimary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                )
                                : Container(
                                  width: 6.5,
                                  height: 6.5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF94A3B8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
