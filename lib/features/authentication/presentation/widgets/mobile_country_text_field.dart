import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/core/widgets/shiiftex_text_field.dart';

class CountryCodeOption {
  final String code;
  final String country;
  final String flag;

  const CountryCodeOption({
    required this.code,
    required this.country,
    required this.flag,
  });
}

class MobileCountryTextField extends StatelessWidget {
  final TextEditingController controller;
  final String selectedCountryCode;
  final ValueChanged<String> onCountryCodeChanged;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const MobileCountryTextField({
    super.key,
    required this.controller,
    required this.selectedCountryCode,
    required this.onCountryCodeChanged,
    this.validator,
    this.onChanged,
  });

  static const List<CountryCodeOption> supportedCountries = [
    CountryCodeOption(code: '+91', country: 'India', flag: '🇮🇳'),
    CountryCodeOption(code: '+1', country: 'United States', flag: '🇺🇸'),
    CountryCodeOption(code: '+44', country: 'United Kingdom', flag: '🇬🇧'),
    CountryCodeOption(
      code: '+971',
      country: 'United Arab Emirates',
      flag: '🇦🇪',
    ),
    CountryCodeOption(code: '+65', country: 'Singapore', flag: '🇸🇬'),
    CountryCodeOption(code: '+61', country: 'Australia', flag: '🇦🇺'),
  ];

  void _showCountryPicker(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      constraints: BoxConstraints(maxHeight: maxHeight),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.dragHandle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Select Country Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: supportedCountries.length,
                    itemBuilder: (context, index) {
                      final option = supportedCountries[index];
                      final isSelected = option.code == selectedCountryCode;
                      return ListTile(
                        leading: Text(
                          option.flag,
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          option.country,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        trailing: Text(
                          option.code,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color:
                                isSelected
                                    ? AppColors.primaryBlue
                                    : AppColors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          onCountryCodeChanged(option.code);
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShiiftexTextField(
      controller: controller,
      hintText: 'Mobile number',
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
      customPrefix: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.phone_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showCountryPicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inputCountryPill,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedCountryCode,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
