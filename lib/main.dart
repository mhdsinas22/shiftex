import 'package:flutter/material.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/injection_container.dart';
import 'package:shiftex/shiftexapp.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDependencies();
  getIt<AuthenticationBloc>().add(const AuthSessionChanged());
  runApp(const Shiftexapp());
}
