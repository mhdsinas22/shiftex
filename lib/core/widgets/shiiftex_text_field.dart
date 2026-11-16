import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/constants/app_spacing.dart';
import 'package:shiftex/core/utils/responsive_layout.dart';

class ShiiftexTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? customPrefix;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;
  final FocusNode? focusNode;
  final AutovalidateMode? autovalidateMode;

  const ShiiftexTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.customPrefix,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.enabled = true,
    this.contentPadding,
    this.focusNode,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final verticalPad = responsive.isShortScreen ? 13.5 : 16.0;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      enabled: enabled,
      autovalidateMode: autovalidateMode,
      scrollPadding: const EdgeInsets.only(bottom: 120),
      style: TextStyle(
        fontSize: responsive.isSmallWidth ? 13.8 : 14.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: responsive.isSmallWidth ? 13.8 : 14.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textHint,
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
        isDense: true,
        errorMaxLines: 2,
        contentPadding:
            contentPadding ??
            EdgeInsets.symmetric(
              horizontal: prefixIcon == null && customPrefix == null ? 18 : 14,
              vertical: verticalPad,
            ),
        prefixIcon:
            customPrefix ??
            (prefixIcon != null
                ? Padding(
                  padding: const EdgeInsets.only(left: 16, right: 10),
                  child: Icon(
                    prefixIcon,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                )
                : null),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 0,
          minHeight: 0,
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(
            color: AppColors.errorRed,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(
            color: AppColors.errorRed,
            width: 1.4,
          ),
        ),
        errorStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: AppColors.errorRed,
          height: 1.25,
        ),
      ),
    );
  }
}
