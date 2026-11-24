import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiftex/core/constants/app_colors.dart';

/// Numeric positive-integer input for custom claim points with live pts badge.
class CustomPointsInput extends StatefulWidget {
  final String value;
  final double discountInr;
  final bool enabled;
  final String? validationError;
  final ValueChanged<String> onChanged;

  const CustomPointsInput({
    super.key,
    required this.value,
    required this.discountInr,
    required this.onChanged,
    this.enabled = true,
    this.validationError,
  });

  @override
  State<CustomPointsInput> createState() => _CustomPointsInputState();
}

class _CustomPointsInputState extends State<CustomPointsInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant CustomPointsInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError =
        widget.validationError != null && widget.validationError!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Custom Amount (pts)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasError ? AppColors.errorRed : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.primaryBlue,
                    child: Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: widget.onChanged,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8EF63C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'pts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B2405),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.validationError!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.errorRed,
            ),
          ),
        ],
      ],
    );
  }
}
