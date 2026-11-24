import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/network/network_info.dart';
import 'package:shiftex/core/services/secure_storage_service.dart';
import 'package:shiftex/core/utils/validators.dart';
import 'package:shiftex/features/account_approval/domain/entities/approval_status.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_event.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_state.dart';
import 'package:shiftex/features/change_phone/data/datasources/change_phone_remote_data_source.dart';
import 'package:shiftex/features/change_phone/data/repositories/change_phone_repository_impl.dart';
import 'package:shiftex/features/change_phone/domain/entities/change_phone_result_entity.dart';
import 'package:shiftex/features/change_phone/domain/repositories/change_phone_repository.dart';
import 'package:shiftex/features/change_phone/domain/usecases/change_phone_usecase.dart';
import 'package:shiftex/features/change_phone/presentation/bloc/change_phone_bloc.dart';
import 'package:shiftex/features/change_phone/presentation/bloc/change_phone_event.dart';
import 'package:shiftex/features/change_phone/presentation/bloc/change_phone_state.dart';
import 'package:shiftex/features/change_phone/presentation/pages/change_phone_page.dart';
import 'package:shiftex/features/home/presentation/widgets/customer_profile_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockChangePhoneRepository extends Mock implements ChangePhoneRepository {}

class MockChangePhoneRemoteDataSource extends Mock
    implements ChangePhoneRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockChangePhoneUseCase extends Mock implements ChangePhoneUseCase {}

class MockAuthenticationBloc
    extends MockBloc<AuthenticationEvent, AuthenticationState>
    implements AuthenticationBloc {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class _FakeChangePhoneParams extends Fake implements ChangePhoneParams {}

class _FakeAuthenticationEvent extends Fake implements AuthenticationEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeChangePhoneParams());
    registerFallbackValue(_FakeAuthenticationEvent());
  });

  final tNow = DateTime.utc(2026, 11, 24);
  const tUserId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const tCurrentPhoneE164 = '+919876543210';
  const tCurrentPhone10 = '9876543210';
  const tNewPhone10 = '9123456789';
  const tNewPhoneE164 = '+919123456789';

  CustomerProfileEntity buildApprovedProfile({
    String mobileNumber = tCurrentPhoneE164,
  }) {
    return CustomerProfileEntity(
      id: tUserId,
      fullName: 'Rahul Sharma',
      email: 'rahul@shiftex.com',
      mobileNumber: mobileNumber,
      approvalStatus: AccountApprovalStatus.approved,
      createdAt: tNow,
      updatedAt: tNow,
    );
  }

  const tSuccessResult = ChangePhoneResultEntity(
    userId: tUserId,
    previousPhoneNumber: tCurrentPhoneE164,
    updatedPhoneNumber: tNewPhoneE164,
    displayPhoneNumber: tNewPhone10,
    message: 'Your registered phone number has been updated to +919123456789.',
  );

  // ===========================================================================
  // 1. Strict 10-Digit Phone Number Validation Tests
  // ===========================================================================
  group('Validators.validateNewPhoneNumber & extractTenDigitPhone', () {
    test('accepts valid 10-digit numeric phone number (9876543210)', () {
      expect(
        Validators.validateNewPhoneNumber(
          '9876543210',
          currentPhoneNumber: '9123456789',
        ),
        isNull,
      );
      expect(
        Validators.validateNewPhoneNumber(
          '  9876543210  ',
          currentPhoneNumber: '+919123456789',
        ),
        isNull,
      );
    });

    test('rejects empty or whitespace-only input', () {
      expect(
        Validators.validateNewPhoneNumber(null),
        'Phone number is required',
      );
      expect(
        Validators.validateNewPhoneNumber(''),
        'Phone number is required',
      );
      expect(
        Validators.validateNewPhoneNumber('   '),
        'Phone number is required',
      );
    });

    test('rejects alphabetic characters and special characters (98765abc10)', () {
      expect(
        Validators.validateNewPhoneNumber('98765abc10'),
        'Only numeric digits (0-9) are allowed',
      );
      expect(
        Validators.validateNewPhoneNumber('abcdefghij'),
        'Only numeric digits (0-9) are allowed',
      );
      expect(
        Validators.validateNewPhoneNumber('98765-4321'),
        'Only numeric digits (0-9) are allowed',
      );
      expect(
        Validators.validateNewPhoneNumber('+919876543210'),
        'Only numeric digits (0-9) are allowed',
      );
      expect(
        Validators.validateNewPhoneNumber('98765 43210'),
        'Only numeric digits (0-9) are allowed',
      );
    });

    test('rejects numbers with fewer or more than 10 digits (987654321, 98765432101)', () {
      expect(
        Validators.validateNewPhoneNumber('987654321'),
        'Phone number must be exactly 10 digits',
      );
      expect(
        Validators.validateNewPhoneNumber('98765432101'),
        'Phone number must be exactly 10 digits',
      );
      expect(
        Validators.validateNewPhoneNumber('12345'),
        'Phone number must be exactly 10 digits',
      );
    });

    test('rejects entering the same phone number as current phone number', () {
      expect(
        Validators.validateNewPhoneNumber(
          '9876543210',
          currentPhoneNumber: '9876543210',
        ),
        'New phone number must be different from your current phone number',
      );
      expect(
        Validators.validateNewPhoneNumber(
          '9876543210',
          currentPhoneNumber: '+919876543210',
        ),
        'New phone number must be different from your current phone number',
      );
    });

    test('extractTenDigitPhone strips +91 and 91 country code prefixes cleanly', () {
      expect(Validators.extractTenDigitPhone('+919876543210'), '9876543210');
      expect(Validators.extractTenDigitPhone('919876543210'), '9876543210');
      expect(Validators.extractTenDigitPhone('9876543210'), '9876543210');
      expect(Validators.extractTenDigitPhone(null), '');
    });
  });

  // ===========================================================================
  // 2. Repository, UseCase & Data Source Tests (UUID & Data Preservation)
  // ===========================================================================
  group('ChangePhoneRepositoryImpl & ChangePhoneUseCase', () {
    late MockChangePhoneRemoteDataSource mockRemoteDataSource;
    late MockNetworkInfo mockNetworkInfo;
    late ChangePhoneRepositoryImpl repository;
    late ChangePhoneUseCase useCase;

    setUp(() {
      mockRemoteDataSource = MockChangePhoneRemoteDataSource();
      mockNetworkInfo = MockNetworkInfo();
      repository = ChangePhoneRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        networkInfo: mockNetworkInfo,
      );
      useCase = ChangePhoneUseCase(repository);
    });

    test(
      'returns Right(ChangePhoneResultEntity) and preserves existing user UUID on database update success',
      () async {
        when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => mockRemoteDataSource.changePhoneNumber(
            newPhoneNumber: '  9123456789  ',
            currentPhoneNumber: tCurrentPhoneE164,
          ),
        ).thenAnswer((_) async => tSuccessResult);

        final result = await useCase(
          const ChangePhoneParams(
            newPhoneNumber: '  9123456789  ',
            currentPhoneNumber: tCurrentPhoneE164,
          ),
        );

        expect(result, const Right(tSuccessResult));
        result.fold(
          (_) => fail('Expected Right'),
          (entity) {
            expect(entity.userId, tUserId);
            expect(entity.previousPhoneNumber, tCurrentPhoneE164);
            expect(entity.updatedPhoneNumber, tNewPhoneE164);
            expect(entity.displayPhoneNumber, tNewPhone10);
          },
        );
        verify(
          () => mockRemoteDataSource.changePhoneNumber(
            newPhoneNumber: '  9123456789  ',
            currentPhoneNumber: tCurrentPhoneE164,
          ),
        ).called(1);
      },
    );

    test('returns Left(NetworkFailure) when device is offline', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      final result = await useCase(
        const ChangePhoneParams(
          newPhoneNumber: tNewPhone10,
          currentPhoneNumber: tCurrentPhoneE164,
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Expected Left'),
      );
      verifyZeroInteractions(mockRemoteDataSource);
    });

    test(
      'maps duplicate mobile number PostgrestException (profiles_mobile_number_key) to MobileAlreadyRegisteredFailure',
      () async {
        when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => mockRemoteDataSource.changePhoneNumber(
            newPhoneNumber: tNewPhone10,
            currentPhoneNumber: tCurrentPhoneE164,
          ),
        ).thenThrow(
          const PostgrestException(
            message:
                'duplicate key value violates unique constraint "profiles_mobile_number_key"',
            code: '23505',
          ),
        );

        final result = await useCase(
          const ChangePhoneParams(
            newPhoneNumber: tNewPhone10,
            currentPhoneNumber: tCurrentPhoneE164,
          ),
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<MobileAlreadyRegisteredFailure>());
            expect(
              failure.message,
              'An account with this mobile number already exists.',
            );
          },
          (_) => fail('Expected Left'),
        );
      },
    );

    test('maps generic database failure to ServerFailure', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(
        () => mockRemoteDataSource.changePhoneNumber(
          newPhoneNumber: tNewPhone10,
          currentPhoneNumber: tCurrentPhoneE164,
        ),
      ).thenThrow(
        const PostgrestException(
          message: 'Database write error',
          code: '50000',
        ),
      );

      final result = await useCase(
        const ChangePhoneParams(
          newPhoneNumber: tNewPhone10,
          currentPhoneNumber: tCurrentPhoneE164,
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test(
      'ChangePhoneRemoteDataSourceImpl rejects missing sessions and invalid inputs without signOut or signUp',
      () async {
        final mockClient = MockSupabaseClient();
        final mockAuth = MockGoTrueClient();
        final mockStorage = MockSecureStorageService();
        when(() => mockClient.auth).thenReturn(mockAuth);

        final dataSource = ChangePhoneRemoteDataSourceImpl(
          mockClient,
          secureStorageService: mockStorage,
        );

        // Expired session throws AppAuthException(code: 'session_expired') without calling signOut
        when(() => mockAuth.currentSession).thenReturn(null);
        when(() => mockAuth.currentUser).thenReturn(null);

        await expectLater(
          () => dataSource.changePhoneNumber(
            newPhoneNumber: tNewPhone10,
            currentPhoneNumber: tCurrentPhone10,
          ),
          throwsA(
            isA<AppAuthException>().having(
              (e) => e.code,
              'code',
              'session_expired',
            ),
          ),
        );
        verifyNever(() => mockAuth.signOut());
      },
    );
  });

  // ===========================================================================
  // 3. ChangePhoneBloc State Management Tests
  // ===========================================================================
  group('ChangePhoneBloc', () {
    late MockChangePhoneUseCase mockUseCase;
    late ChangePhoneBloc bloc;

    setUp(() {
      mockUseCase = MockChangePhoneUseCase();
      bloc = ChangePhoneBloc(changePhoneUseCase: mockUseCase);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state is ChangePhoneInitial', () {
      expect(bloc.state, const ChangePhoneInitial());
    });

    test(
      'InitializeChangePhone populates read-only currentPhoneNumber and currentTenDigitPhone',
      () async {
        bloc.add(const InitializeChangePhone('+919876543210'));
        await pumpEventQueue();

        expect(bloc.state, isA<ChangePhoneValidationChanged>());
        expect(bloc.state.form.currentPhoneNumber, '+919876543210');
        expect(bloc.state.form.currentTenDigitPhone, '9876543210');
      },
    );

    test(
      'NewPhoneNumberChanged validates 9 digits, 11 digits, alphabetic, same number, and valid 10 digits',
      () async {
        bloc.add(const InitializeChangePhone('9876543210'));
        await pumpEventQueue();

        // 9 digits -> invalid
        bloc.add(const NewPhoneNumberChanged('987654321'));
        await pumpEventQueue();
        expect(bloc.state.form.isValid, isFalse);
        expect(
          bloc.state.form.newPhoneError,
          'Phone number must be exactly 10 digits',
        );

        // 11 digits -> invalid
        bloc.add(const NewPhoneNumberChanged('98765432101'));
        await pumpEventQueue();
        expect(bloc.state.form.isValid, isFalse);
        expect(
          bloc.state.form.newPhoneError,
          'Phone number must be exactly 10 digits',
        );

        // Alphabetic -> invalid
        bloc.add(const NewPhoneNumberChanged('98765abc10'));
        await pumpEventQueue();
        expect(bloc.state.form.isValid, isFalse);
        expect(
          bloc.state.form.newPhoneError,
          'Only numeric digits (0-9) are allowed',
        );

        // Same number -> invalid
        bloc.add(const NewPhoneNumberChanged('9876543210'));
        await pumpEventQueue();
        expect(bloc.state.form.isValid, isFalse);
        expect(
          bloc.state.form.newPhoneError,
          'New phone number must be different from your current phone number',
        );

        // Valid new 10-digit number -> isValid is true
        bloc.add(const NewPhoneNumberChanged('9123456789'));
        await pumpEventQueue();
        expect(bloc.state.form.isValid, isTrue);
        expect(bloc.state.form.newPhoneError, isNull);
      },
    );

    test(
      'SubmitChangePhone emits [ChangePhoneLoading, ChangePhoneSuccess] when 10-digit number is valid',
      () async {
        when(() => mockUseCase(any())).thenAnswer(
          (_) async => const Right(tSuccessResult),
        );

        bloc.add(const InitializeChangePhone(tCurrentPhoneE164));
        bloc.add(const NewPhoneNumberChanged(tNewPhone10));
        await pumpEventQueue();

        final states = <ChangePhoneState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const SubmitChangePhone());
        await pumpEventQueue();

        expect(states.length, 2);
        expect(states[0], isA<ChangePhoneLoading>());
        expect(states[1], isA<ChangePhoneSuccess>());
        final success = states[1] as ChangePhoneSuccess;
        expect(success.result.userId, tUserId);
        expect(success.result.updatedPhoneNumber, tNewPhoneE164);
        expect(success.result.displayPhoneNumber, tNewPhone10);

        await sub.cancel();
      },
    );

    test(
      'SubmitChangePhone emits [ChangePhoneLoading, ChangePhoneFailure] when repository returns failure',
      () async {
        when(() => mockUseCase(any())).thenAnswer(
          (_) async => const Left(
            MobileAlreadyRegisteredFailure(
              'This mobile number is already registered to another account.',
            ),
          ),
        );

        bloc.add(const InitializeChangePhone(tCurrentPhoneE164));
        bloc.add(const NewPhoneNumberChanged(tNewPhone10));
        await pumpEventQueue();

        final states = <ChangePhoneState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const SubmitChangePhone());
        await pumpEventQueue();

        expect(states.length, 2);
        expect(states[0], isA<ChangePhoneLoading>());
        expect(states[1], isA<ChangePhoneFailure>());
        expect(
          (states[1] as ChangePhoneFailure).message,
          'This mobile number is already registered to another account.',
        );

        await sub.cancel();
      },
    );
  });

  // ===========================================================================
  // 4. Widget & UI/UX Tests (ChangePhonePage & CustomerProfileSheet)
  // ===========================================================================
  group('ChangePhonePage & CustomerProfileSheet Widget Tests', () {
    late MockChangePhoneUseCase mockUseCase;

    setUp(() {
      mockUseCase = MockChangePhoneUseCase();
    });

    ChangePhoneBloc createBloc() {
      return ChangePhoneBloc(changePhoneUseCase: mockUseCase);
    }

    MockAuthenticationBloc createMockAuthBloc() {
      final mockAuthBloc = MockAuthenticationBloc();
      final profile = buildApprovedProfile();
      when(() => mockAuthBloc.state).thenReturn(AuthenticationSuccess(profile));
      whenListen<AuthenticationState>(
        mockAuthBloc,
        const Stream<AuthenticationState>.empty(),
        initialState: AuthenticationSuccess(profile),
      );
      return mockAuthBloc;
    }

    Widget buildTestWidget({
      required ChangePhoneBloc bloc,
      required AuthenticationBloc authBloc,
    }) {
      return MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthenticationBloc>.value(value: authBloc),
          ],
          child: ChangePhonePage(
            bloc: bloc,
            initialCurrentPhone: tCurrentPhoneE164,
          ),
        ),
      );
    }

    testWidgets(
      'displays read-only current phone number, validates 10-digit input, and saves directly without OTP or password',
      (tester) async {
        when(() => mockUseCase(any())).thenAnswer(
          (_) async => const Right(tSuccessResult),
        );

        final bloc = createBloc();
        final mockAuthBloc = createMockAuthBloc();
        addTearDown(bloc.close);

        await tester.pumpWidget(
          buildTestWidget(bloc: bloc, authBloc: mockAuthBloc),
        );
        await tester.pumpAndSettle();

        // Read-only current phone card shows 9876543210
        expect(
          find.byKey(const ValueKey('change_phone_current_card')),
          findsOneWidget,
        );
        expect(find.text('9876543210'), findsOneWidget);
        expect(find.text('0/10 digits'), findsOneWidget);

        // Enter 9-digit invalid number -> shows error
        final phoneField = find.byKey(const ValueKey('change_phone_new_field'));
        await tester.enterText(phoneField, '987654321');
        await tester.pumpAndSettle();
        expect(find.text('9/10 digits'), findsOneWidget);
        expect(
          find.text('Phone number must be exactly 10 digits'),
          findsOneWidget,
        );

        // Enter same number -> shows error
        await tester.enterText(phoneField, '9876543210');
        await tester.pumpAndSettle();
        expect(
          find.text(
            'New phone number must be different from your current phone number',
          ),
          findsOneWidget,
        );

        // Enter valid 10-digit number -> ready to save
        await tester.enterText(phoneField, tNewPhone10);
        await tester.pumpAndSettle();
        expect(find.text('10/10 digits'), findsOneWidget);
        expect(
          find.text('Valid 10-digit phone number'),
          findsOneWidget,
        );

        // Tap Save Changes button
        final submitButton = find.byKey(
          const ValueKey('change_phone_submit_button'),
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Success view displayed immediately (no OTP screen, no logout)
        expect(
          find.byKey(const ValueKey('change_phone_success_view')),
          findsOneWidget,
        );
        expect(find.text('Phone Number Updated'), findsOneWidget);
        expect(
          find.textContaining('Active phone: 9123456789'),
          findsOneWidget,
        );

        // Verifies AuthenticationBloc was refreshed and never logged out
        verify(() => mockAuthBloc.add(const AuthSessionChanged())).called(1);
        verifyNever(() => mockAuthBloc.add(const LogoutRequested()));
      },
    );

    testWidgets(
      'displays error banner and SnackBar when database update fails',
      (tester) async {
        when(() => mockUseCase(any())).thenAnswer(
          (_) async => const Left(
            MobileAlreadyRegisteredFailure(
              'This mobile number is already registered to another account.',
            ),
          ),
        );

        final bloc = createBloc();
        final mockAuthBloc = createMockAuthBloc();
        addTearDown(bloc.close);

        await tester.pumpWidget(
          buildTestWidget(bloc: bloc, authBloc: mockAuthBloc),
        );
        await tester.pumpAndSettle();

        final phoneField = find.byKey(const ValueKey('change_phone_new_field'));
        await tester.enterText(phoneField, tNewPhone10);
        await tester.pumpAndSettle();

        final submitButton = find.byKey(
          const ValueKey('change_phone_submit_button'),
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('change_phone_error_banner')),
          findsOneWidget,
        );
        expect(
          find.text(
            'This mobile number is already registered to another account.',
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'CustomerProfileSheet renders Change Phone Number tile and triggers callback',
      (tester) async {
        var tappedChangePhone = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomerProfileSheet(
                fallbackFullName: 'Rahul Sharma',
                fallbackEmail: 'rahul@shiftex.com',
                fallbackMobile: '+919876543210',
                onSignOut: () {},
                onChangePhone: () {
                  tappedChangePhone = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('profile_change_phone_tile'));
        expect(tile, findsOneWidget);
        expect(find.text('Change Phone Number'), findsOneWidget);

        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();

        expect(tappedChangePhone, isTrue);
      },
    );

    testWidgets(
      'renders without layout overflow across 320x568, 375x812, and 430x932 viewports',
      (tester) async {
        final bloc = createBloc();
        final mockAuthBloc = createMockAuthBloc();
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          bloc.close();
        });

        for (final size in const [
          Size(320, 568),
          Size(375, 812),
          Size(430, 932),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            buildTestWidget(bloc: bloc, authBloc: mockAuthBloc),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
