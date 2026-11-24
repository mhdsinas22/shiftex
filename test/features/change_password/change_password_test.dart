import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/network/network_info.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/core/theme/app_theme.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:shiftex/features/change_password/data/datasources/change_password_remote_data_source.dart';
import 'package:shiftex/features/change_password/data/repositories/change_password_repository_impl.dart';
import 'package:shiftex/features/change_password/domain/usecases/change_password_usecase.dart';
import 'package:shiftex/features/change_password/presentation/bloc/change_password_bloc.dart';
import 'package:shiftex/features/change_password/presentation/bloc/change_password_event.dart';
import 'package:shiftex/features/change_password/presentation/bloc/change_password_state.dart';
import 'package:shiftex/features/change_password/presentation/pages/change_password_page.dart';
import 'package:shiftex/features/home/presentation/widgets/customer_profile_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockUser extends Mock implements User {}

class _MockSession extends Mock implements Session {}

class _MockAuthResponse extends Mock implements AuthResponse {}

class _MockUserResponse extends Mock implements UserResponse {}

class _MockChangePasswordUseCase extends Mock
    implements ChangePasswordUseCase {}

class _MockAuthenticationBloc
    extends MockBloc<AuthenticationEvent, AuthenticationState>
    implements AuthenticationBloc {}

class _FakeChangePasswordParams extends Fake implements ChangePasswordParams {}

class _FakeUserAttributes extends Fake implements UserAttributes {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeChangePasswordParams());
    registerFallbackValue(_FakeUserAttributes());
  });

  group('ChangePasswordRemoteDataSource & Repository Tests', () {
    late _MockSupabaseClient mockSupabaseClient;
    late _MockGoTrueClient mockAuthClient;
    late _MockNetworkInfo mockNetworkInfo;
    late _MockUser mockUser;
    late _MockSession mockSession;
    late _MockAuthResponse mockAuthResponse;
    late _MockUserResponse mockUserResponse;
    late ChangePasswordRemoteDataSourceImpl remoteDataSource;
    late ChangePasswordRepositoryImpl repository;

    setUp(() {
      mockSupabaseClient = _MockSupabaseClient();
      mockAuthClient = _MockGoTrueClient();
      mockNetworkInfo = _MockNetworkInfo();
      mockUser = _MockUser();
      mockSession = _MockSession();
      mockAuthResponse = _MockAuthResponse();
      mockUserResponse = _MockUserResponse();

      when(() => mockSupabaseClient.auth).thenReturn(mockAuthClient);
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);

      when(() => mockUser.email).thenReturn('rahul@example.com');
      when(() => mockSession.isExpired).thenReturn(false);
      when(() => mockAuthResponse.user).thenReturn(mockUser);
      when(() => mockAuthResponse.session).thenReturn(mockSession);
      when(() => mockUserResponse.user).thenReturn(mockUser);

      remoteDataSource = ChangePasswordRemoteDataSourceImpl(mockSupabaseClient);
      repository = ChangePasswordRepositoryImpl(
        remoteDataSource: remoteDataSource,
        networkInfo: mockNetworkInfo,
      );
    });

    test(
      'returns SessionExpiredFailure when no authenticated session exists',
      () async {
        when(() => mockAuthClient.currentSession).thenReturn(null);
        when(() => mockAuthClient.currentUser).thenReturn(null);

        final result = await repository.changePassword(
          currentPassword: 'OldPass1!',
          newPassword: 'NewPass1!',
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<SessionExpiredFailure>()),
          (_) => fail('Expected failure'),
        );
        verifyNever(
          () => mockAuthClient.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
    );

    test(
      'refreshes expired session, verifies current password, updates password without signing out',
      () async {
        when(() => mockSession.isExpired).thenReturn(true);
        when(() => mockAuthClient.currentSession).thenReturn(mockSession);
        when(() => mockAuthClient.currentUser).thenReturn(mockUser);
        when(
          () => mockAuthClient.refreshSession(),
        ).thenAnswer((_) async => mockAuthResponse);
        when(
          () => mockAuthClient.signInWithPassword(
            email: 'rahul@example.com',
            password: 'OldPass1!',
          ),
        ).thenAnswer((_) async => mockAuthResponse);
        when(
          () => mockAuthClient.updateUser(any()),
        ).thenAnswer((_) async => mockUserResponse);

        final result = await repository.changePassword(
          currentPassword: 'OldPass1!',
          newPassword: 'NewPass1!',
        );

        expect(result, const Right<Failure, Unit>(unit));
        verifyInOrder([
          () => mockAuthClient.refreshSession(),
          () => mockAuthClient.signInWithPassword(
            email: 'rahul@example.com',
            password: 'OldPass1!',
          ),
          () => mockAuthClient.updateUser(
            any(
              that: isA<UserAttributes>().having(
                (attrs) => attrs.password,
                'password',
                'NewPass1!',
              ),
            ),
          ),
        ]);
        verifyNever(() => mockAuthClient.signOut());
      },
    );

    test(
      'returns InvalidCredentialsFailure with clear message when current password is wrong',
      () async {
        when(() => mockAuthClient.currentSession).thenReturn(mockSession);
        when(() => mockAuthClient.currentUser).thenReturn(mockUser);
        when(
          () => mockAuthClient.signInWithPassword(
            email: 'rahul@example.com',
            password: 'WrongPass1!',
          ),
        ).thenThrow(
          const AuthException(
            'Invalid login credentials',
            code: 'invalid_credentials',
          ),
        );

        final result = await repository.changePassword(
          currentPassword: 'WrongPass1!',
          newPassword: 'NewPass1!',
        );

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<InvalidCredentialsFailure>());
          expect(
            failure.message,
            'Current password is incorrect. Please check and try again.',
          );
        }, (_) => fail('Expected failure'));
        verifyNever(() => mockAuthClient.updateUser(any()));
        verifyNever(() => mockAuthClient.signOut());
      },
    );

    test(
      'returns NetworkFailure immediately when device is offline',
      () async {
        when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.changePassword(
          currentPassword: 'OldPass1!',
          newPassword: 'NewPass1!',
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('Expected NetworkFailure'),
        );
        verifyNever(() => mockAuthClient.currentSession);
      },
    );

    test('maps rate limit, socket failure, and weak password cleanly', () async {
      when(() => mockAuthClient.currentSession).thenReturn(mockSession);
      when(() => mockAuthClient.currentUser).thenReturn(mockUser);
      when(
        () => mockAuthClient.signInWithPassword(
          email: 'rahul@example.com',
          password: 'OldPass1!',
        ),
      ).thenAnswer((_) async => mockAuthResponse);

      when(() => mockAuthClient.updateUser(any())).thenThrow(
        const AuthException(
          'Too many requests',
          code: 'over_request_rate_limit',
        ),
      );
      final rateLimitResult = await repository.changePassword(
        currentPassword: 'OldPass1!',
        newPassword: 'NewPass1!',
      );
      rateLimitResult.fold(
        (failure) => expect(failure, isA<RateLimitFailure>()),
        (_) => fail('Expected RateLimitFailure'),
      );

      when(() => mockAuthClient.updateUser(any())).thenThrow(
        const AuthException('Password too weak', code: 'weak_password'),
      );
      final weakResult = await repository.changePassword(
        currentPassword: 'OldPass1!',
        newPassword: 'NewPass1!',
      );
      weakResult.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected ValidationFailure'),
      );

      when(
        () => mockAuthClient.updateUser(any()),
      ).thenThrow(const SocketException('No internet'));
      final networkResult = await repository.changePassword(
        currentPassword: 'OldPass1!',
        newPassword: 'NewPass1!',
      );
      networkResult.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Expected NetworkFailure'),
      );
    });

    test('never leaks plaintext passwords via toString()', () {
      const params = ChangePasswordParams(
        currentPassword: 'SecretCurrent1!',
        newPassword: 'SecretNew1!',
      );
      const event = CurrentPasswordChanged('SecretCurrent1!');
      final form = ChangePasswordFormData.evaluate(
        currentPassword: 'SecretCurrent1!',
        newPassword: 'SecretNew1!',
        confirmPassword: 'SecretNew1!',
        obscureCurrentPassword: true,
        obscureNewPassword: true,
        obscureConfirmPassword: true,
        currentTouched: true,
        newTouched: true,
        confirmTouched: true,
      );

      expect(params.toString(), isNot(contains('SecretCurrent1!')));
      expect(params.toString(), isNot(contains('SecretNew1!')));
      expect(event.toString(), isNot(contains('SecretCurrent1!')));
      expect(form.toString(), isNot(contains('SecretCurrent1!')));
      expect(form.toString(), isNot(contains('SecretNew1!')));
    });
  });

  group('ChangePasswordBloc Tests', () {
    late _MockChangePasswordUseCase mockUseCase;

    setUp(() {
      mockUseCase = _MockChangePasswordUseCase();
    });

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'tracks real-time password validation, strength level, and mismatch',
      build: () => ChangePasswordBloc(changePasswordUseCase: mockUseCase),
      act: (bloc) {
        bloc.add(const CurrentPasswordChanged('OldPass1!'));
        bloc.add(const NewPasswordChanged('weak'));
        bloc.add(const NewPasswordChanged('StrongPass1!'));
        bloc.add(const ConfirmPasswordChanged('StrongPass1!'));
      },
      verify: (bloc) {
        final state = bloc.state;
        expect(state, isA<ChangePasswordValidationChanged>());
        expect(state.form.hasMinLength, isTrue);
        expect(state.form.hasUppercase, isTrue);
        expect(state.form.hasLowercase, isTrue);
        expect(state.form.hasNumber, isTrue);
        expect(state.form.hasSpecialChar, isTrue);
        expect(state.form.passwordsMatch, isTrue);
        expect(state.form.isDifferentFromCurrent, isTrue);
        expect(state.form.strength, PasswordStrengthLevel.strong);
        expect(state.form.isValid, isTrue);
      },
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'blocks same-password updates in real-time form evaluation',
      build: () => ChangePasswordBloc(changePasswordUseCase: mockUseCase),
      act: (bloc) {
        bloc.add(const CurrentPasswordChanged('StrongPass1!'));
        bloc.add(const NewPasswordChanged('StrongPass1!'));
        bloc.add(const ConfirmPasswordChanged('StrongPass1!'));
      },
      verify: (bloc) {
        expect(bloc.state.form.isDifferentFromCurrent, isFalse);
        expect(bloc.state.form.isValid, isFalse);
      },
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'prevents duplicate submissions while ChangePasswordLoading is active',
      build: () {
        final completer = Completer<Either<Failure, Unit>>();
        when(() => mockUseCase(any())).thenAnswer((_) => completer.future);
        return ChangePasswordBloc(changePasswordUseCase: mockUseCase);
      },
      act: (bloc) async {
        bloc.add(const CurrentPasswordChanged('OldPass1!'));
        bloc.add(const NewPasswordChanged('NewStrongPass1!'));
        bloc.add(const ConfirmPasswordChanged('NewStrongPass1!'));
        bloc.add(const SubmitChangePassword());
        bloc.add(const SubmitChangePassword());
      },
      verify: (bloc) {
        verify(() => mockUseCase(any())).called(1);
        expect(bloc.state, isA<ChangePasswordLoading>());
      },
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'emits Loading then Failure on error and allows toggling visibility and editing',
      build: () {
        when(() => mockUseCase(any())).thenAnswer(
          (_) async => const Left(
            InvalidCredentialsFailure(
              'Current password is incorrect. Please check and try again.',
            ),
          ),
        );
        return ChangePasswordBloc(changePasswordUseCase: mockUseCase);
      },
      act: (bloc) async {
        bloc.add(const CurrentPasswordChanged('WrongPass1!'));
        bloc.add(const NewPasswordChanged('NewStrongPass1!'));
        bloc.add(const ConfirmPasswordChanged('NewStrongPass1!'));
        bloc.add(const SubmitChangePassword());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ToggleCurrentPasswordVisibility());
      },
      verify: (bloc) {
        expect(bloc.state, isA<ChangePasswordFailure>());
        expect(bloc.state.form.obscureCurrentPassword, isFalse);
      },
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'emits Loading then Success and clears password strings from state',
      build: () {
        when(() => mockUseCase(any())).thenAnswer(
          (_) async => const Right<Failure, Unit>(unit),
        );
        return ChangePasswordBloc(changePasswordUseCase: mockUseCase);
      },
      act: (bloc) {
        bloc.add(const CurrentPasswordChanged('OldPass1!'));
        bloc.add(const NewPasswordChanged('NewStrongPass1!'));
        bloc.add(const ConfirmPasswordChanged('NewStrongPass1!'));
        bloc.add(const SubmitChangePassword());
      },
      expect: () => [
        isA<ChangePasswordValidationChanged>(),
        isA<ChangePasswordValidationChanged>(),
        isA<ChangePasswordValidationChanged>(),
        isA<ChangePasswordLoading>(),
        isA<ChangePasswordSuccess>(),
      ],
      verify: (bloc) {
        expect(bloc.state.form.currentPassword, isEmpty);
        expect(bloc.state.form.newPassword, isEmpty);
        expect(bloc.state.form.confirmPassword, isEmpty);
      },
    );
  });

  group('ChangePasswordPage & Profile Navigation Widget Tests', () {
    late _MockChangePasswordUseCase mockUseCase;

    setUp(() {
      mockUseCase = _MockChangePasswordUseCase();
    });

    Widget buildStandalonePage(ChangePasswordBloc bloc, {Size? size}) {
      final child = MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChangePasswordPage(bloc: bloc),
      );
      if (size == null) return child;
      return MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      );
    }

    testWidgets(
      'displays complete UI, updates live strength & toggles visibility, and completes update flow',
      (tester) async {
        when(() => mockUseCase(any())).thenAnswer(
          (_) async => const Right<Failure, Unit>(unit),
        );
        final bloc = ChangePasswordBloc(changePasswordUseCase: mockUseCase);
        addTearDown(bloc.close);

        await tester.pumpWidget(buildStandalonePage(bloc));
        await tester.pumpAndSettle();

        expect(find.text('Change Password'), findsOneWidget);
        expect(find.text('Secure your account'), findsOneWidget);
        expect(find.text('Update Your Password'), findsOneWidget);
        expect(
          find.text('Keep your account secure by using a strong password'),
          findsOneWidget,
        );
        expect(find.text('Password Strength'), findsOneWidget);
        expect(find.text('At least 8 characters'), findsOneWidget);

        // Button is initially disabled while inputs are empty.
        final initialButton = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.byKey(const ValueKey('change_password_submit_button')),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(initialButton.onPressed, isNull);

        // Enter passwords across all three fields.
        await tester.enterText(
          find.byKey(const ValueKey('change_password_current_field')),
          'OldPass1!',
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_password_new_field')),
          'NewStrongPass1!',
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_password_confirm_field')),
          'NewStrongPass1!',
        );
        await tester.pumpAndSettle();

        expect(find.text('Strong'), findsOneWidget);
        expect(find.text('Passwords match'), findsOneWidget);

        // Visibility toggle flips obscureText independently.
        final newFieldBefore = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('change_password_new_field')),
            matching: find.byType(TextField),
          ),
        );
        expect(newFieldBefore.obscureText, isTrue);

        await tester.tap(
          find.byKey(const ValueKey('new_password_visibility_toggle')),
        );
        await tester.pumpAndSettle();

        final newFieldAfter = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('change_password_new_field')),
            matching: find.byType(TextField),
          ),
        );
        expect(newFieldAfter.obscureText, isFalse);

        // Scroll to submit button and submit form.
        final submitFinder = find.byKey(
          const ValueKey('change_password_submit_button'),
        );
        await tester.ensureVisible(submitFinder);
        await tester.pumpAndSettle();

        final enabledButton = tester.widget<ElevatedButton>(
          find.descendant(
            of: submitFinder,
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(enabledButton.onPressed, isNotNull);

        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        expect(find.text('Password Updated Successfully'), findsOneWidget);
        expect(
          find.text('Your account password has been changed.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('change_password_done_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'displays error banner when Supabase current password verification fails',
      (tester) async {
        when(() => mockUseCase(any())).thenAnswer(
          (_) async => const Left(
            InvalidCredentialsFailure(
              'Current password is incorrect. Please check and try again.',
            ),
          ),
        );
        final bloc = ChangePasswordBloc(changePasswordUseCase: mockUseCase);
        addTearDown(bloc.close);

        await tester.pumpWidget(buildStandalonePage(bloc));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('change_password_current_field')),
          'WrongPass1!',
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_password_new_field')),
          'NewStrongPass1!',
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_password_confirm_field')),
          'NewStrongPass1!',
        );
        await tester.pumpAndSettle();

        final submitFinder = find.byKey(
          const ValueKey('change_password_submit_button'),
        );
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Current password is incorrect. Please check and try again.',
          ),
          findsOneWidget,
        );
        expect(find.text('Password Updated Successfully'), findsNothing);
      },
    );

    testWidgets(
      'navigates from Profile Security -> Change Password via GoRouter and pops back cleanly on Done',
      (tester) async {
        when(() => mockUseCase(any())).thenAnswer(
          (_) async => const Right<Failure, Unit>(unit),
        );
        final bloc = ChangePasswordBloc(changePasswordUseCase: mockUseCase);
        addTearDown(bloc.close);

        late GoRouter router;
        router = GoRouter(
          initialLocation: RoutesNames.home,
          routes: [
            GoRoute(
              path: RoutesNames.home,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      final activeRouter = GoRouter.maybeOf(context);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CustomerProfileSheet(
                          fallbackFullName: 'Rahul Sharma',
                          fallbackEmail: 'rahul@example.com',
                          fallbackMobile: '+919876543210',
                          onChangePassword: () {
                            activeRouter?.push(RoutesNames.changePassword);
                          },
                          onSignOut: () {},
                        ),
                      );
                    },
                    child: const Text('Open Profile'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: RoutesNames.changePassword,
              builder: (context, state) => ChangePasswordPage(bloc: bloc),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Profile'));
        await tester.pumpAndSettle();

        expect(find.text('Security'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('profile_change_password_tile')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('profile_change_password_tile')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Update Your Password'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('change_password_current_field')),
          'OldPass1!',
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_password_new_field')),
          'NewStrongPass1!',
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_password_confirm_field')),
          'NewStrongPass1!',
        );
        await tester.pumpAndSettle();

        final submitFinder = find.byKey(
          const ValueKey('change_password_submit_button'),
        );
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        expect(find.text('Password Updated Successfully'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('change_password_done_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Open Profile'), findsOneWidget);
      },
    );

    testWidgets(
      'displays Forgot Password? option in Change Password, navigates to ForgotPasswordPage with registered email, and returns cleanly',
      (tester) async {
        final mockAuthBloc = _MockAuthenticationBloc();
        final now = DateTime.utc(2026, 11, 22);
        final profile = CustomerProfileEntity(
          id: 'user-1',
          fullName: 'Rahul Sharma',
          email: 'rahul@example.com',
          mobileNumber: '+919876543210',
          approvalStatus: AccountApprovalStatus.approved,
          createdAt: now,
          updatedAt: now,
        );
        when(() => mockAuthBloc.state).thenReturn(AuthenticationSuccess(profile));
        whenListen<AuthenticationState>(
          mockAuthBloc,
          const Stream<AuthenticationState>.empty(),
          initialState: AuthenticationSuccess(profile),
        );

        final changePasswordBloc = ChangePasswordBloc(
          changePasswordUseCase: mockUseCase,
        );
        addTearDown(changePasswordBloc.close);

        final router = GoRouter(
          initialLocation: RoutesNames.changePassword,
          routes: [
            GoRoute(
              path: RoutesNames.changePassword,
              builder: (context, state) => ChangePasswordPage(
                bloc: changePasswordBloc,
              ),
            ),
            GoRoute(
              path: RoutesNames.forgotPassword,
              builder: (context, state) => ForgotPasswordPage(
                initialEmail: state.uri.queryParameters['email'],
                fromChangePassword:
                    state.uri.queryParameters['from'] == 'change-password',
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: mockAuthBloc,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final forgotButton = find.byKey(
          const ValueKey('change_password_forgot_password_button'),
        );
        expect(forgotButton, findsOneWidget);

        await tester.tap(forgotButton);
        await tester.pumpAndSettle();

        expect(find.text('Send Reset Code'), findsOneWidget);
        expect(find.text('r••••••••l@example.com'), findsOneWidget);
        expect(find.text('Back to Change Password'), findsOneWidget);

        await tester.ensureVisible(find.text('Back to Change Password'));
        await tester.tap(find.text('Back to Change Password'));
        await tester.pumpAndSettle();

        expect(find.text('Update Your Password'), findsOneWidget);
      },
    );

    testWidgets(
      'restores session and returns to ChangePasswordPage when Back to Change Password is tapped after PasswordResetEmailSent',
      (tester) async {
        final mockAuthBloc = _MockAuthenticationBloc();
        final authController =
            StreamController<AuthenticationState>.broadcast();
        addTearDown(authController.close);

        final now = DateTime.utc(2026, 11, 22);
        final profile = CustomerProfileEntity(
          id: 'user-1',
          fullName: 'Rahul Sharma',
          email: 'rahul@example.com',
          mobileNumber: '+919876543210',
          approvalStatus: AccountApprovalStatus.approved,
          createdAt: now,
          updatedAt: now,
        );
        const sentState = PasswordResetEmailSent(email: 'rahul@example.com');
        when(() => mockAuthBloc.state).thenReturn(sentState);
        whenListen<AuthenticationState>(
          mockAuthBloc,
          authController.stream,
          initialState: sentState,
        );

        final changePasswordBloc = ChangePasswordBloc(
          changePasswordUseCase: mockUseCase,
        );
        addTearDown(changePasswordBloc.close);

        final router = GoRouter(
          initialLocation:
              '${RoutesNames.forgotPassword}?email=rahul%40example.com&from=change-password',
          routes: [
            GoRoute(
              path: RoutesNames.forgotPassword,
              builder: (context, state) => ForgotPasswordPage(
                initialEmail: state.uri.queryParameters['email'],
                fromChangePassword:
                    state.uri.queryParameters['from'] == 'change-password',
              ),
            ),
            GoRoute(
              path: RoutesNames.changePassword,
              builder: (context, state) => ChangePasswordPage(
                bloc: changePasswordBloc,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: mockAuthBloc,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final backButton = find.text('Back to Change Password');
        await tester.ensureVisible(backButton);
        await tester.tap(backButton);
        await tester.pump();

        verify(() => mockAuthBloc.add(const AuthSessionChanged())).called(1);

        when(() => mockAuthBloc.state).thenReturn(AuthenticationSuccess(profile));
        authController.add(AuthenticationSuccess(profile));
        await tester.pumpAndSettle();

        expect(find.text('Update Your Password'), findsOneWidget);
      },
    );

    testWidgets(
      'wrong current password error banner surfaces inline Reset via email action',
      (tester) async {
        when(() => mockUseCase(any())).thenAnswer(
          (_) async => const Left(
            InvalidCredentialsFailure(
              'Current password is incorrect. Please check and try again.',
            ),
          ),
        );
        var forgotTapped = false;
        final bloc = ChangePasswordBloc(changePasswordUseCase: mockUseCase);
        addTearDown(bloc.close);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: ChangePasswordPage(
              bloc: bloc,
              onForgotPassword: () => forgotTapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('change_password_current_field')),
          'WrongPass1!',
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_password_new_field')),
          'NewStrongPass1!',
        );
        await tester.enterText(
          find.byKey(const ValueKey('change_password_confirm_field')),
          'NewStrongPass1!',
        );
        await tester.pumpAndSettle();

        final submitFinder = find.byKey(
          const ValueKey('change_password_submit_button'),
        );
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        final inlineResetFinder = find.byKey(
          const ValueKey('change_password_failure_forgot_password_button'),
        );
        expect(inlineResetFinder, findsOneWidget);

        await tester.ensureVisible(inlineResetFinder);
        await tester.tap(inlineResetFinder);
        await tester.pumpAndSettle();

        expect(forgotTapped, isTrue);
      },
    );

    for (final viewport in const [
      Size(320, 568),
      Size(375, 812),
      Size(430, 932),
    ]) {
      testWidgets(
        'renders ChangePasswordPage without overflow at ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final bloc = ChangePasswordBloc(changePasswordUseCase: mockUseCase);
          addTearDown(bloc.close);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(size: viewport),
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: ChangePasswordPage(bloc: bloc),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Update Your Password'), findsOneWidget);
        },
      );
    }
  });
}
