import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';

enum KeypadBottomLeftVariant {
  fingerprint,
  pasteCard,
}

class ShiiftexNumericKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback? onPastePressed;
  final KeypadBottomLeftVariant bottomLeftVariant;
  final bool boxedActionKeys;

  const ShiiftexNumericKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    this.onPastePressed,
    this.bottomLeftVariant = KeypadBottomLeftVariant.fingerprint,
    this.boxedActionKeys = false,
  });

  static const List<Map<String, String>> _keys = [
    {'digit': '1', 'letters': ''},
    {'digit': '2', 'letters': 'ABC'},
    {'digit': '3', 'letters': 'DEF'},
    {'digit': '4', 'letters': 'GHI'},
    {'digit': '5', 'letters': 'JKL'},
    {'digit': '6', 'letters': 'MNO'},
    {'digit': '7', 'letters': 'PQRS'},
    {'digit': '8', 'letters': 'TUV'},
    {'digit': '9', 'letters': 'WXYZ'},
  ];

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final keyHeight = responsive.keypadKeyHeight;
    final rowGap = responsive.keypadRowGap;
    final colGap = responsive.isSmallWidth ? 8.0 : 10.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int row = 0; row < 3; row++) ...[
          Row(
            children: [
              for (int col = 0; col < 3; col++) ...[
                if (col > 0) SizedBox(width: colGap),
                Expanded(
                  child: _DigitKeyButton(
                    digit: _keys[row * 3 + col]['digit']!,
                    letters: _keys[row * 3 + col]['letters']!,
                    height: keyHeight,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onDigitPressed(_keys[row * 3 + col]['digit']!);
                    },
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: rowGap),
        ],
        Row(
          children: [
            Expanded(
              child: _buildBottomLeftKey(keyHeight),
            ),
            SizedBox(width: colGap),
            Expanded(
              child: _DigitKeyButton(
                digit: '0',
                letters: '+',
                height: keyHeight,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onDigitPressed('0');
                },
              ),
            ),
            SizedBox(width: colGap),
            Expanded(
              child: _buildBackspaceKey(keyHeight),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomLeftKey(double height) {
    final isBoxed = bottomLeftVariant == KeypadBottomLeftVariant.pasteCard;
    return Material(
      color: isBoxed ? AppColors.keypadButtonBg : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap:
            onPastePressed != null
                ? () {
                  HapticFeedback.selectionClick();
                  onPastePressed?.call();
                }
                : null,
        child: SizedBox(
          height: height,
          child: Center(
            child: Icon(
              isBoxed ? Icons.assignment_outlined : Icons.fingerprint_rounded,
              size: isBoxed ? 21 : 25,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(double height) {
    return Material(
      color: boxedActionKeys ? AppColors.keypadButtonBg : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onBackspacePressed();
        },
        child: SizedBox(
          height: height,
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              size: boxedActionKeys ? 20 : 22,
              color:
                  boxedActionKeys
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DigitKeyButton extends StatelessWidget {
  final String digit;
  final String letters;
  final double height;
  final VoidCallback onTap;

  const _DigitKeyButton({
    required this.digit,
    required this.letters,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = height < 46;
    return Material(
      color: AppColors.keypadButtonBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                digit,
                style: TextStyle(
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.05,
                ),
              ),
              if (letters.isNotEmpty) ...[
                const SizedBox(height: 1.5),
                Text(
                  letters,
                  style: TextStyle(
                    fontSize: compact ? 7.8 : 8.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
