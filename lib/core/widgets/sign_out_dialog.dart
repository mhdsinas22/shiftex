import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';

void signOutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return BlocConsumer<AuthenticationBloc, AuthenticationState>(
        builder: (context, state) {
          final isLoading = state is AuthenticationLoading;
          return AlertDialog(
            backgroundColor: AppColors.white,
            title: Text("SignOut"),
            content: Text('Are you sure you want to sign out of your account?'),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        context.read<AuthenticationBloc>().add(
                          LogoutRequested(),
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
                        "SignOut",
                        style: TextStyle(color: AppColors.errorRed),
                      ),
              ),
            ],
          );
        },
        listener: (context, state) {
          if (state is Unauthenticated) {
            Navigator.of(dialogContext).pop();
          } else if (state is AuthenticationFailure) {
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Un Authenction the user")));
          }
        },
      );
    },
  );
}
