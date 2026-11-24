import 'package:flutter/material.dart';
import 'package:shiftex/core/widgets/password_strength_card.dart';
import 'package:shiftex/features/change_password/presentation/bloc/change_password_state.dart';

/// Displays the animated 4-segment strength bar and real-time 5-rule checklist
/// derived from [ChangePasswordFormData].
class PasswordStrengthMeter extends StatelessWidget {
  final ChangePasswordFormData form;

  const PasswordStrengthMeter({super.key, required this.form});

  @override
  Widget build(BuildContext context) {
    return PasswordStrengthCard(
      password: form.newPassword,
      showCurrentPasswordDifferenceWarning: !form.isDifferentFromCurrent,
    );
  }
}
