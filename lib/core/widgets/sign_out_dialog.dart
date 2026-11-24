import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';

void signOutDialog(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  showDialog(
    context: context,
    builder: (dialogContext) {
      return BlocConsumer<AuthenticationBloc, AuthenticationState>(
        builder: (context, state) {
          final isLoading = state is AuthenticationLoading;
          return PopScope(
            canPop: !isLoading,
            child: AlertDialog(
              backgroundColor: AppColors.white,
              title: const Text("Sign Out"),
              content: const Text(
                'Are you sure you want to sign out of your account?',
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          if (dialogContext.mounted &&
                              Navigator.of(dialogContext).canPop()) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          context.read<AuthenticationBloc>().add(
                            const LogoutRequested(),
                          );
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.errorRed,
                          ),
                        )
                      : Text(
                          "Sign Out",
                          style: TextStyle(color: AppColors.errorRed),
                        ),
                ),
              ],
            ),
          );
        },
        listener: (context, state) {
          if (state is Unauthenticated) {
            if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          } else if (state is AuthenticationFailure) {
            if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
            messenger?.showSnackBar(
              SnackBar(content: Text(state.failure.message)),
            );
          }
        },
      );
    },
  );
}
