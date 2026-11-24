import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/core/widgets/password_strength_card.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/authentication/presentation/pages/registration_page.dart';
import 'package:shiftex/features/authentication/presentation/pages/set_new_password_page.dart';

class _MockAuthenticationBloc
    extends MockBloc<AuthenticationEvent, AuthenticationState>
    implements AuthenticationBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ResetPasswordRequested(newPassword: ''));
    registerFallbackValue(
      const RegisterRequested(
        firstName: '',
        lastName: '',
        mobileNumber: '',
        email: '',
        password: '',
      ),
    );
  });

  group('Validators.validateStrongPassword Unit Tests', () {
    test('rejects empty, short, missing upper/lower/digit/special and accepts strong password', () {
      expect(Validators.validateStrongPassword(''), 'Password is required');
      expect(
        Validators.validateStrongPassword('Abc1!'),
        'Password must be at least 8 characters',
      );
      expect(
        Validators.validateStrongPassword('abcdef1!'),
        'Include at least 1 uppercase letter',
      );
      expect(
        Validators.validateStrongPassword('ABCDEF1!'),
        'Include at least 1 lowercase letter',
      );
      expect(
        Validators.validateStrongPassword('Abcdefg!'),
        'Include at least 1 number',
      );
      expect(
        Validators.validateStrongPassword('Abcdefg1'),
        'Include at least 1 special character',
      );
      expect(Validators.validateStrongPassword('Abcdef1!'), isNull);
    });
  });

  group('PasswordStrengthCard & SetNewPasswordPage (Forgot Password)', () {
    testWidgets(
      'displays live Password Strength meter & 5 rules, blocks weak passwords, and submits strong password',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAuthBloc = _MockAuthenticationBloc();
        when(() => mockAuthBloc.state).thenReturn(
          const PasswordResetVerified(email: 'customer@example.com'),
        );

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: mockAuthBloc,
            child: const MaterialApp(home: SetNewPasswordPage()),
          ),
        );

        expect(find.byType(PasswordStrengthCard), findsOneWidget);
        expect(find.text('Password Strength'), findsOneWidget);
        expect(find.text('Not set'), findsOneWidget);
        expect(find.text('At least 8 characters'), findsOneWidget);
        expect(find.text('At least 1 uppercase letter (A-Z)'), findsOneWidget);
        expect(find.text('At least 1 lowercase letter (a-z)'), findsOneWidget);
        expect(find.text('At least 1 number (0-9)'), findsOneWidget);
        expect(
          find.text('At least 1 special character (!@#...)'),
          findsOneWidget,
        );

        // Weak password -> blocks submission with clear validation error
        await tester.enterText(
          find.widgetWithText(TextFormField, 'New password'),
          'Abcdefg1',
        );
        await tester.pump();
        expect(find.text('Good'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm new password'),
          'Abcdefg1',
        );
        await tester.ensureVisible(find.text('Update Password'));
        await tester.pump();
        await tester.tap(find.text('Update Password'));
        await tester.pump();

        expect(find.text('Include at least 1 special character'), findsOneWidget);
        verifyNever(() => mockAuthBloc.add(any()));

        // Strong password mismatch -> blocked
        await tester.enterText(
          find.widgetWithText(TextFormField, 'New password'),
          'StrongPass1!',
        );
        await tester.pump();
        expect(find.text('Strong'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm new password'),
          'Mismatch1!',
        );
        await tester.tap(find.text('Update Password'));
        await tester.pump();
        expect(find.text('Passwords do not match'), findsOneWidget);
        verifyNever(() => mockAuthBloc.add(any()));

        // Matching strong password -> dispatches ResetPasswordRequested
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm new password'),
          'StrongPass1!',
        );
        await tester.tap(find.text('Update Password'));
        await tester.pump();

        verify(
          () => mockAuthBloc.add(
            const ResetPasswordRequested(newPassword: 'StrongPass1!'),
          ),
        ).called(1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'SetNewPasswordPage renders cleanly without overflow on compact 320x568 viewport',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAuthBloc = _MockAuthenticationBloc();
        when(() => mockAuthBloc.state).thenReturn(
          const PasswordResetVerified(email: 'customer@example.com'),
        );

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: mockAuthBloc,
            child: const MaterialApp(home: SetNewPasswordPage()),
          ),
        );
        await tester.pump();

        expect(find.text('Password Strength'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('PasswordStrengthCard & RegistrationPage (Create Password)', () {
    testWidgets(
      'displays live Password Strength meter & 5 rules, blocks weak passwords, and submits strong registration',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAuthBloc = _MockAuthenticationBloc();
        when(() => mockAuthBloc.state).thenReturn(const Unauthenticated());

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: mockAuthBloc,
            child: const MaterialApp(home: RegistrationPage()),
          ),
        );

        expect(find.byType(PasswordStrengthCard), findsOneWidget);
        expect(find.text('Password Strength'), findsOneWidget);
        expect(find.text('Not set'), findsOneWidget);
        expect(find.text('At least 8 characters'), findsOneWidget);
        expect(find.text('At least 1 uppercase letter (A-Z)'), findsOneWidget);
        expect(find.text('At least 1 lowercase letter (a-z)'), findsOneWidget);
        expect(find.text('At least 1 number (0-9)'), findsOneWidget);
        expect(
          find.text('At least 1 special character (!@#...)'),
          findsOneWidget,
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'First name'),
          'Rahul',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Last name'),
          'Sharma',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Mobile number'),
          '9876543210',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'name@example.com'),
          'rahul@example.com',
        );

        // Progressive strength levels: Weak -> Fair -> Good -> Strong
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Create password'),
          'ab',
        );
        await tester.pump();
        expect(find.text('Weak'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Create password'),
          'Abcdefgh',
        );
        await tester.pump();
        expect(find.text('Fair'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Create password'),
          'Password1',
        );
        await tester.pump();
        expect(find.text('Good'), findsOneWidget);

        await tester.ensureVisible(find.text('Create account'));
        await tester.pump();
        await tester.tap(find.text('Create account'));
        await tester.pump();

        expect(find.text('Include at least 1 special character'), findsOneWidget);
        verifyNever(() => mockAuthBloc.add(any()));

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Create password'),
          'Password1!',
        );
        await tester.pump();
        expect(find.text('Strong'), findsOneWidget);

        await tester.ensureVisible(find.text('Create account'));
        await tester.pump();
        await tester.tap(find.text('Create account'));
        await tester.pump();

        verify(
          () => mockAuthBloc.add(
            const RegisterRequested(
              firstName: 'Rahul',
              lastName: 'Sharma',
              mobileNumber: '+919876543210',
              email: 'rahul@example.com',
              password: 'Password1!',
            ),
          ),
        ).called(1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'RegistrationPage renders cleanly without overflow on compact 320x568 viewport',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAuthBloc = _MockAuthenticationBloc();
        when(() => mockAuthBloc.state).thenReturn(const Unauthenticated());

        await tester.pumpWidget(
          BlocProvider<AuthenticationBloc>.value(
            value: mockAuthBloc,
            child: const MaterialApp(home: RegistrationPage()),
          ),
        );
        await tester.pump();

        expect(find.text('Password Strength'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
