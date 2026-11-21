import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/routes/routes_names.dart';
import 'package:shiftex/features/account_approval/domain/usecases/get_approval_status_usecase.dart';
import 'package:shiftex/features/activity_history/data/datasources/activity_history_remote_data_source.dart';
import 'package:shiftex/features/activity_history/data/datasources/statement_exporter_service.dart';
import 'package:shiftex/features/activity_history/data/models/activity_history_models.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_filter.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_history_page_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_wallet_summary_entity.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';
import 'package:shiftex/features/activity_history/domain/usecases/export_monthly_statement_usecase.dart';
import 'package:shiftex/features/activity_history/domain/usecases/get_activity_history_usecase.dart';
import 'package:shiftex/features/activity_history/domain/usecases/get_transaction_detail_usecase.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_bloc.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_event.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_state.dart';
import 'package:shiftex/features/activity_history/presentation/pages/activity_history_page.dart';
import 'package:shiftex/features/activity_history/presentation/widgets/transaction_date_group.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:shiftex/features/authentication/domain/usecases/forgot_password_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/get_current_session_profile_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/login_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/logout_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/register_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/resend_email_otp_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/reset_password_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/verify_email_otp_usecase.dart';
import 'package:shiftex/features/authentication/domain/usecases/verify_password_reset_otp_usecase.dart';
import 'package:shiftex/features/authentication/presentation/bloc/authentication_bloc.dart';
import 'package:shiftex/features/home/domain/entities/daily_streak_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/domain/entities/wallet_summary_entity.dart';
import 'package:shiftex/features/home/domain/usecases/generate_claim_qr_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:shiftex/features/home/domain/usecases/track_advertisement_event_usecase.dart';
import 'package:shiftex/features/home/presentation/bloc/home_bloc.dart';
import 'package:shiftex/features/home/presentation/pages/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockGetActivityHistoryUseCase extends Mock
    implements GetActivityHistoryUseCase {}

class _MockGetTransactionDetailUseCase extends Mock
    implements GetTransactionDetailUseCase {}

class _MockExportMonthlyStatementUseCase extends Mock
    implements ExportMonthlyStatementUseCase {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockGetHomeDashboardUseCase extends Mock
    implements GetHomeDashboardUseCase {}

class _MockGenerateClaimQrUseCase extends Mock
    implements GenerateClaimQrUseCase {}

class _MockTrackAdvertisementEventUseCase extends Mock
    implements TrackAdvertisementEventUseCase {}

class _MockRegisterUseCase extends Mock implements RegisterUseCase {}

class _MockVerifyEmailOtpUseCase extends Mock
    implements VerifyEmailOtpUseCase {}

class _MockResendEmailOtpUseCase extends Mock
    implements ResendEmailOtpUseCase {}

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockLogoutUseCase extends Mock implements LogoutUseCase {}

class _MockForgotPasswordUseCase extends Mock
    implements ForgotPasswordUseCase {}

class _MockVerifyPasswordResetOtpUseCase extends Mock
    implements VerifyPasswordResetOtpUseCase {}

class _MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

class _MockGetCurrentSessionProfileUseCase extends Mock
    implements GetCurrentSessionProfileUseCase {}

class _MockGetApprovalStatusUseCase extends Mock
    implements GetApprovalStatusUseCase {}

class _MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  final tNow = DateTime(2026, 11, 18, 15, 0);

  ActivityWalletSummaryEntity buildSummary({
    int netAvailablePoints = 2450,
    double rate = 0.10,
    int lifetimeEarnedPoints = 3200,
    double lifetimeEarnedInr = 350.0,
    int totalRedeemedPoints = 750,
    double totalRedeemedInr = 75.0,
    int lockedPoints = 120,
    bool hasDiscrepancy = false,
  }) {
    return ActivityWalletSummaryEntity(
      customerCode: 'SHFT-81F6',
      membershipTier: 'Pebble Black Member',
      netAvailablePoints: netAvailablePoints,
      netAvailableInr: netAvailablePoints * rate,
      reservedPoints: 0,
      lockedPoints: lockedPoints,
      lockedInr: lockedPoints * rate,
      lifetimeEarnedPoints: lifetimeEarnedPoints,
      lifetimeEarnedInr: lifetimeEarnedInr,
      totalRedeemedPoints: totalRedeemedPoints,
      totalRedeemedInr: totalRedeemedInr,
      walletLifetimeEarnedPoints: lifetimeEarnedPoints,
      currentPointsToInrRate: rate,
      currentPointsPerRupee: (1.0 / rate).round(),
      currencyCode: 'INR',
      timezone: 'Asia/Kolkata',
      reconciliation: LedgerReconciliationEntity(
        hasDiscrepancy: hasDiscrepancy,
        availableOffsetPoints: hasDiscrepancy ? 10 : 0,
        lockedOffsetPoints: hasDiscrepancy ? 10 : 0,
        expectedAvailableFromLedger:
            hasDiscrepancy ? netAvailablePoints - 10 : netAvailablePoints,
        expectedLockedFromAllocations:
            hasDiscrepancy ? lockedPoints - 10 : lockedPoints,
      ),
    );
  }

  ActivityTransactionEntity buildPosTx({
    String id = 'tx-pos-1',
    DateTime? createdAt,
  }) {
    final dt = createdAt ?? DateTime.utc(2026, 11, 18, 9, 0);
    return ActivityTransactionEntity(
      id: id,
      recordSource: 'ledger',
      kind: ActivityKind.posPurchase,
      transactionType: 'merchant_reward',
      title: 'Counter #1 POS',
      description: 'Purchase reward • Bill #OK',
      referenceCode: 'TXN-E485EC',
      pointsDelta: 120,
      availablePointsPart: 50,
      lockedPointsPart: 70,
      historicalInrValue: 6.00,
      historicalRate: 0.05,
      historicalPointsPerRupee: 20,
      currencyCode: 'INR',
      status: 'Partially Locked',
      createdAt: dt,
      details: ActivityTransactionDetailsEntity(
        merchantName: 'Counter #1 POS',
        terminalId: 'Counter #1 POS',
        billNumber: 'OK',
        purchaseAmount: 1200.0,
        instantPoints: 50,
        futureLockedPoints: 70,
        unlockAt: dt.add(const Duration(days: 7)),
        allocationStatus: 'locked',
      ),
    );
  }

  ActivityTransactionEntity buildClaimTx({
    String id = 'tx-claim-1',
    DateTime? createdAt,
  }) {
    final dt = createdAt ?? DateTime.utc(2026, 11, 17, 10, 0);
    return ActivityTransactionEntity(
      id: id,
      recordSource: 'ledger',
      kind: ActivityKind.claimRedemption,
      transactionType: 'discount_redemption',
      title: 'Claim Verified & Redeemed',
      description: 'Redeemed 250 pts • Bill #ORD-FD4109',
      referenceCode: 'TXN-D2A0F7',
      pointsDelta: -250,
      availablePointsPart: 0,
      lockedPointsPart: 0,
      historicalInrValue: 25.00, // Historical 0.10 rate preserved!
      historicalRate: 0.10,
      historicalPointsPerRupee: 10,
      currencyCode: 'INR',
      status: 'Completed',
      createdAt: dt,
      details: ActivityTransactionDetailsEntity(
        merchantName: 'ShiftEx Partner Counter',
        terminalId: 'Counter #1 POS',
        claimVoucherCode: 'CLM-8456-012',
        rewardName: 'Instant POS Bill Discount',
        orderReference: 'ORD-FD4109',
        billNumber: 'ORD-FD4109',
        redeemedAt: dt,
        auditStatus: 'verified',
        auditReference: 'AUD-8456-012',
      ),
    );
  }

  ActivityTransactionEntity buildStreakTx({
    String id = 'tx-streak-1',
    DateTime? createdAt,
  }) {
    final dt = createdAt ?? DateTime.utc(2026, 11, 16, 4, 0);
    return ActivityTransactionEntity(
      id: id,
      recordSource: 'ledger',
      kind: ActivityKind.dailyStreak,
      transactionType: 'daily_streak',
      title: 'Daily Streak Bonus',
      description: 'Day 2 of 7 check-in (locks on Day 7)',
      referenceCode: 'TXN-B600F8',
      pointsDelta: 20,
      availablePointsPart: 0,
      lockedPointsPart: 20,
      historicalInrValue: 1.00,
      historicalRate: 0.05,
      historicalPointsPerRupee: 20,
      currencyCode: 'INR',
      status: 'In Progress',
      createdAt: dt,
      details: const ActivityTransactionDetailsEntity(
        streakDay: 2,
        cycleReference: '2026-11-18',
        inProgressStreak: true,
      ),
    );
  }

  ActivityTransactionEntity buildReleaseTx({
    String id = 'tx-release-1',
    DateTime? createdAt,
  }) {
    final dt = createdAt ?? DateTime.utc(2026, 10, 29, 8, 0);
    return ActivityTransactionEntity(
      id: id,
      recordSource: 'ledger',
      kind: ActivityKind.lockedRelease,
      transactionType: 'streak_unlock',
      title: 'Locked Points Unlocked',
      description: 'POS Future Reward unlocked to available balance',
      referenceCode: 'TXN-REL001',
      pointsDelta: 70,
      availablePointsPart: 70,
      lockedPointsPart: 0,
      historicalInrValue: 7.00,
      historicalRate: 0.10,
      historicalPointsPerRupee: 10,
      currencyCode: 'INR',
      status: 'Released',
      createdAt: dt,
      details: ActivityTransactionDetailsEntity(
        unlockedAt: dt,
        allocationStatus: 'unlocked',
      ),
    );
  }

  MonthlyStatementEntity buildStatement() {
    return MonthlyStatementEntity(
      customerName: 'Vishnu Kumar',
      membershipId: 'SHFT-81F6',
      year: 2026,
      month: 11,
      timezone: 'Asia/Kolkata',
      openingAvailableBalance: 100,
      totalEarnedPoints: 350,
      totalEarnedInr: 17.50,
      totalRedeemedPoints: 250,
      totalRedeemedInr: 25.00,
      lockedAllocatedPoints: 70,
      lockedReleasedPoints: 0,
      closingAvailableBalance: 150, // 100 + 300 - 250 = 150
      generatedAt: DateTime.utc(2026, 11, 18, 10, 0),
      items: [
        StatementLineItemEntity(
          transactionId: 'TXN-POS01',
          rawId: 'tx-pos-1',
          transactionType: 'merchant_reward',
          title: 'POS Reward Allocated',
          description: 'Bill #OK • Instant',
          pointsCredited: 300,
          pointsDeducted: 0,
          historicalInr: 15.00,
          historicalRate: 0.05,
          currencyCode: 'INR',
          isLockedAllocation: false,
          status: 'Completed',
          createdAt: DateTime.utc(2026, 11, 18, 9, 0),
        ),
        StatementLineItemEntity(
          transactionId: 'TXN-POS02',
          rawId: 'tx-pos-2',
          transactionType: 'merchant_reward',
          title: 'Future POS Reward Locked',
          description: 'Bill #OK (7d hold)',
          pointsCredited: 70,
          pointsDeducted: 0,
          historicalInr: 3.50,
          historicalRate: 0.05,
          currencyCode: 'INR',
          isLockedAllocation: true,
          status: 'Locked',
          createdAt: DateTime.utc(2026, 11, 18, 9, 0),
        ),
        StatementLineItemEntity(
          transactionId: 'TXN-CLM01',
          rawId: 'tx-claim-1',
          transactionType: 'discount_redemption',
          title: 'Claim Verified & Redeemed',
          description: 'Redeemed 250 pts • Bill #ORD-FD4109',
          pointsCredited: 0,
          pointsDeducted: 250,
          historicalInr: 25.00,
          historicalRate: 0.10,
          currencyCode: 'INR',
          isLockedAllocation: false,
          status: 'Completed',
          createdAt: DateTime.utc(2026, 11, 18, 9, 30),
        ),
      ],
    );
  }

  AuthenticationBloc buildIdleAuthBloc() {
    final mockAuthRepo = _MockAuthenticationRepository();
    when(
      () => mockAuthRepo.authSessionEvents,
    ).thenAnswer((_) => const Stream.empty());

    return AuthenticationBloc(
      registerUseCase: _MockRegisterUseCase(),
      verifyEmailOtpUseCase: _MockVerifyEmailOtpUseCase(),
      resendEmailOtpUseCase: _MockResendEmailOtpUseCase(),
      loginUseCase: _MockLoginUseCase(),
      logoutUseCase: _MockLogoutUseCase(),
      forgotPasswordUseCase: _MockForgotPasswordUseCase(),
      verifyPasswordResetOtpUseCase: _MockVerifyPasswordResetOtpUseCase(),
      resetPasswordUseCase: _MockResetPasswordUseCase(),
      getCurrentSessionProfileUseCase: _MockGetCurrentSessionProfileUseCase(),
      getApprovalStatusUseCase: _MockGetApprovalStatusUseCase(),
      authRepository: mockAuthRepo,
    );
  }

  setUpAll(() {
    registerFallbackValue(const GetActivityHistoryParams());
    registerFallbackValue(const GetTransactionDetailParams(entryId: 'tx-1'));
    registerFallbackValue(
      const ExportMonthlyStatementParams(
        year: 2026,
        month: 11,
        format: StatementExportFormat.pdf,
      ),
    );
    registerFallbackValue(const GetHomeDashboardParams());
    registerFallbackValue(
      const TrackAdvertisementEventParams(
        advertisementId: '',
        eventType: 'impression',
      ),
    );
  });

  group('Domain, Security, Date Grouping & PDF/CSV Statement Export Tests', () {
    test(
      'Model preserves historical INR values across rate changes and captures ledger discrepancy notice',
      () {
        final page = ActivityHistoryPageModel.fromJson({
          'summary': {
            'customer_code': 'SHFT-81F6',
            'membership_tier': 'Pebble Black Member',
            'net_available_points': 310,
            'net_available_inr': '15.50',
            'reserved_points': 0,
            'locked_points': 110,
            'locked_inr': '5.50',
            'lifetime_earned_points': 650,
            'lifetime_earned_inr': '32.50',
            'total_redeemed_points': 250,
            'total_redeemed_inr': '25.00', // 0.10 historical rate kept!
            'wallet_lifetime_earned_points': 550,
            'current_points_to_inr_rate': '0.050000',
            'current_points_per_rupee': 20,
            'currency_code': 'INR',
            'timezone': 'Asia/Kolkata',
            'reconciliation': {
              'has_discrepancy': true,
              'available_offset_points': 10,
              'locked_offset_points': 10,
              'expected_available_from_ledger': 300,
              'expected_locked_from_allocations': 100,
            },
          },
          'filter': 'all',
          'limit': 20,
          'offset': 0,
          'has_more': false,
          'transactions': [
            {
              'id': 'tx-old-rate',
              'record_source': 'ledger',
              'activity_kind': 'daily_streak',
              'transaction_type': 'daily_streak',
              'title': 'Daily Streak Bonus',
              'description': 'Day 1 check-in',
              'reference_code': 'TXN-OLD01',
              'points_delta': 20,
              'available_points_part': 0,
              'locked_points_part': 20,
              'inr_value': '2.00', // Recorded under old 0.10 rate!
              'historical_rate': '0.100000',
              'points_per_rupee': 10,
              'currency_code': 'INR',
              'status': 'In Progress',
              'created_at': '2026-11-17T05:36:49Z',
            },
          ],
        });

        expect(page.summary.netAvailablePoints, 310);
        expect(page.summary.netAvailableInr, closeTo(15.50, 0.001));
        expect(page.summary.totalRedeemedInr, closeTo(25.00, 0.001));
        expect(page.summary.reconciliation.hasDiscrepancy, isTrue);
        expect(page.summary.reconciliation.availableOffsetPoints, 10);
        expect(page.transactions.first.historicalInrValue, closeTo(2.00, 0.001));
        expect(page.transactions.first.historicalPointsPerRupee, 10);
      },
    );

    test(
      'TransactionDateGrouper accurately groups TODAY, YESTERDAY, THIS WEEK, and older MONTH YEAR sections',
      () {
        final groups = TransactionDateGrouper.group(
          [
            buildPosTx(createdAt: DateTime(2026, 11, 18, 10, 0)),
            buildClaimTx(createdAt: DateTime(2026, 11, 17, 14, 0)),
            buildStreakTx(createdAt: DateTime(2026, 11, 16, 8, 0)),
            buildReleaseTx(createdAt: DateTime(2026, 10, 29, 8, 0)),
          ],
          nowLocal: tNow,
        );

        expect(groups.length, 4);
        expect(groups[0].headerLabel, 'TODAY — 18 Nov 2026');
        expect(groups[1].headerLabel, 'YESTERDAY — 17 Nov 2026');
        expect(groups[2].headerLabel, startsWith('THIS WEEK — 16 Nov'));
        expect(groups[3].headerLabel, 'OCTOBER 2026');
      },
    );

    test(
      'RemoteDataSource rejects unauthenticated calls for customer data isolation',
      () async {
        final mockSupabase = _MockSupabaseClient();
        final mockAuth = _MockGoTrueClient();
        when(() => mockSupabase.auth).thenReturn(mockAuth);
        when(() => mockAuth.currentUser).thenReturn(null);

        final dataSource = ActivityHistoryRemoteDataSourceImpl(mockSupabase);

        expect(
          () => dataSource.getActivityHistory(),
          throwsA(isA<AppAuthException>()),
        );
        expect(
          () => dataSource.getTransactionDetail(entryId: 'tx-1'),
          throwsA(isA<AppAuthException>()),
        );
        expect(
          () => dataSource.getMonthlyStatement(year: 2026, month: 11),
          throwsA(isA<AppAuthException>()),
        );
      },
    );

    test(
      'StatementExporterService generates verified PDF bytes and RFC-4180 CSV ledger',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('shiftex_stmt_');
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final sharedFiles = <String>[];
        final service = StatementExporterService(
          tempDirProvider: () async => tempDir,
          shareFile: (path, mime, subject) async {
            sharedFiles.add('$path|$mime|$subject');
          },
        );

        final statement = buildStatement();

        final pdfResult = await service.generateAndShare(
          statement: statement,
          format: StatementExportFormat.pdf,
        );
        expect(pdfResult.fileName, 'SHIIFTEX_Statement_SHFT-81F6_2026_11.pdf');
        expect(utf8.decode(pdfResult.bytes.take(5).toList()), '%PDF-');

        final csvResult = await service.generateAndShare(
          statement: statement,
          format: StatementExportFormat.csv,
        );
        final csvContent = utf8.decode(csvResult.bytes);
        expect(csvContent, contains('SHFT-81F6'));
        expect(csvContent, contains('Opening Available Balance (pts),100'));
        expect(csvContent, contains('Closing Available Balance (pts),150'));
        expect(csvContent, contains('TXN-CLM01'));
        expect(csvContent, contains('25.00'));
        expect(sharedFiles.length, 2);

        // Balance mismatch throws validation failure cleanly
        final invalidStatement = MonthlyStatementEntity(
          customerName: statement.customerName,
          membershipId: statement.membershipId,
          year: statement.year,
          month: statement.month,
          timezone: statement.timezone,
          openingAvailableBalance: 999,
          totalEarnedPoints: statement.totalEarnedPoints,
          totalEarnedInr: statement.totalEarnedInr,
          totalRedeemedPoints: statement.totalRedeemedPoints,
          totalRedeemedInr: statement.totalRedeemedInr,
          lockedAllocatedPoints: statement.lockedAllocatedPoints,
          lockedReleasedPoints: statement.lockedReleasedPoints,
          closingAvailableBalance: statement.closingAvailableBalance,
          generatedAt: statement.generatedAt,
          items: statement.items,
        );
        expect(
          () => service.validateStatement(invalidStatement),
          throwsA(isA<AppAuthException>()),
        );
      },
    );
  });

  group('ActivityHistoryBloc Tests (Filters, Pagination, Expansion, Export, Errors)', () {
    late _MockGetActivityHistoryUseCase mockGetHistory;
    late _MockGetTransactionDetailUseCase mockGetDetail;
    late _MockExportMonthlyStatementUseCase mockExportStatement;

    setUp(() {
      mockGetHistory = _MockGetActivityHistoryUseCase();
      mockGetDetail = _MockGetTransactionDetailUseCase();
      mockExportStatement = _MockExportMonthlyStatementUseCase();
    });

    blocTest<ActivityHistoryBloc, ActivityHistoryState>(
      'loads summary + paginated list, switches filters (Earned/Claims/DailyStreak), deduplicates pagination, and loads details on expand',
      build: () {
        when(() => mockGetHistory(any())).thenAnswer((invocation) async {
          final params =
              invocation.positionalArguments.first as GetActivityHistoryParams;
          if (params.filter == ActivityFilter.all && params.offset == 0) {
            return Right(
              ActivityHistoryPageEntity(
                summary: buildSummary(),
                filter: ActivityFilter.all,
                limit: 20,
                offset: 0,
                hasMore: true,
                transactions: [buildPosTx(id: 'tx-pos-1')],
              ),
            );
          }
          if (params.filter == ActivityFilter.all && params.offset == 1) {
            // Includes duplicate 'tx-pos-1' + new 'tx-claim-1' to verify deduplication!
            return Right(
              ActivityHistoryPageEntity(
                summary: buildSummary(),
                filter: ActivityFilter.all,
                limit: 20,
                offset: 1,
                hasMore: false,
                transactions: [
                  buildPosTx(id: 'tx-pos-1'),
                  buildClaimTx(id: 'tx-claim-1'),
                ],
              ),
            );
          }
          if (params.filter == ActivityFilter.claims) {
            return Right(
              ActivityHistoryPageEntity(
                summary: buildSummary(),
                filter: ActivityFilter.claims,
                limit: 20,
                offset: 0,
                hasMore: false,
                transactions: [buildClaimTx(id: 'tx-claim-1')],
              ),
            );
          }
          return Right(
            ActivityHistoryPageEntity(
              summary: buildSummary(),
              filter: params.filter,
              limit: 20,
              offset: 0,
              hasMore: false,
              transactions: [buildStreakTx(id: 'tx-streak-1')],
            ),
          );
        });

        when(() => mockGetDetail(any())).thenAnswer(
          (_) async => const Right(
            ActivityTransactionDetailsEntity(
              merchantName: 'Counter #1 POS',
              billNumber: 'OK',
              instantPoints: 50,
              futureLockedPoints: 70,
              allocationStatus: 'locked',
            ),
          ),
        );

        return ActivityHistoryBloc(
          getActivityHistoryUseCase: mockGetHistory,
          getTransactionDetailUseCase: mockGetDetail,
          exportMonthlyStatementUseCase: mockExportStatement,
        );
      },
      act: (bloc) async {
        bloc.add(const ActivityHistoryLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ActivityLoadMoreRequested());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.transactions.length, 2); // Deduplicated cleanly!
        bloc.add(const ActivityTransactionExpandedToggled('tx-pos-1'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.expandedTransactionIds, contains('tx-pos-1'));
        expect(bloc.state.transactions.first.hasLoadedDetailedAudit, isTrue);

        bloc.add(const ActivityFilterChanged(ActivityFilter.claims));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.transactions.single.kind, ActivityKind.claimRedemption);

        bloc.add(const ActivityFilterChanged(ActivityFilter.dailyStreak));
      },
      verify: (bloc) {
        expect(bloc.state.activeFilter, ActivityFilter.dailyStreak);
        expect(bloc.state.transactions.single.kind, ActivityKind.dailyStreak);
        verify(() => mockGetDetail(any())).called(1);
      },
    );

    blocTest<ActivityHistoryBloc, ActivityHistoryState>(
      'emits exporting -> exportSuccess when monthly PDF/CSV statement succeeds',
      build: () {
        when(() => mockExportStatement(any())).thenAnswer(
          (_) async => Right(
            ExportedStatementResultEntity(
              format: StatementExportFormat.pdf,
              fileName: 'SHIIFTEX_Statement_SHFT-81F6_2026_11.pdf',
              filePath: '/tmp/statement.pdf',
              bytes: Uint8List.fromList([1, 2, 3]),
              statement: buildStatement(),
            ),
          ),
        );
        return ActivityHistoryBloc(
          getActivityHistoryUseCase: mockGetHistory,
          getTransactionDetailUseCase: mockGetDetail,
          exportMonthlyStatementUseCase: mockExportStatement,
        );
      },
      act:
          (bloc) => bloc.add(
            const ActivityMonthlyStatementExportRequested(
              year: 2026,
              month: 11,
              format: StatementExportFormat.pdf,
            ),
          ),
      verify: (bloc) {
        expect(bloc.state.status, ActivityHistoryStatus.exportSuccess);
        expect(
          bloc.state.lastExportedStatement?.fileName,
          'SHIIFTEX_Statement_SHFT-81F6_2026_11.pdf',
        );
      },
    );

    blocTest<ActivityHistoryBloc, ActivityHistoryState>(
      'handles error state cleanly on initial load failure',
      build: () {
        when(
          () => mockGetHistory(any()),
        ).thenAnswer((_) async => const Left(NetworkFailure()));
        return ActivityHistoryBloc(
          getActivityHistoryUseCase: mockGetHistory,
          getTransactionDetailUseCase: mockGetDetail,
          exportMonthlyStatementUseCase: mockExportStatement,
        );
      },
      act: (bloc) => bloc.add(const ActivityHistoryLoadRequested()),
      verify: (bloc) {
        expect(bloc.state.status, ActivityHistoryStatus.error);
        expect(bloc.state.errorMessage, contains('Unable to connect'));
      },
    );
  });

  group('ActivityHistoryPage Widget, Navigation & Responsiveness Tests', () {
    late _MockGetActivityHistoryUseCase mockGetHistory;
    late _MockGetTransactionDetailUseCase mockGetDetail;
    late _MockExportMonthlyStatementUseCase mockExportStatement;

    setUp(() {
      mockGetHistory = _MockGetActivityHistoryUseCase();
      mockGetDetail = _MockGetTransactionDetailUseCase();
      mockExportStatement = _MockExportMonthlyStatementUseCase();
    });

    testWidgets(
      'displays wallet summary, locked/available split badges, expandable POS & Claim audit details, and monthly statement export modal',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final now = DateTime.now();
        when(() => mockGetHistory(any())).thenAnswer(
          (_) async => Right(
            ActivityHistoryPageEntity(
              summary: buildSummary(
                netAvailablePoints: 2450,
                rate: 0.10,
                lifetimeEarnedPoints: 3200,
                totalRedeemedPoints: 750,
                lockedPoints: 120,
                hasDiscrepancy: true,
              ),
              filter: ActivityFilter.all,
              limit: 20,
              offset: 0,
              hasMore: false,
              transactions: [
                buildPosTx(createdAt: now.toUtc()),
                buildClaimTx(
                  createdAt: now.subtract(const Duration(days: 1)).toUtc(),
                ),
                buildReleaseTx(
                  createdAt: DateTime(now.year, now.month - 1, 12).toUtc(),
                ),
              ],
            ),
          ),
        );
        when(() => mockGetDetail(any())).thenAnswer((invocation) async {
          final params =
              invocation.positionalArguments.first as GetTransactionDetailParams;
          if (params.entryId == 'tx-claim-1') {
            return Right(buildClaimTx().details);
          }
          return Right(
            ActivityTransactionDetailsEntity(
              merchantName: 'Counter #1 POS',
              billNumber: 'OK',
              instantPoints: 50,
              futureLockedPoints: 70,
              unlockAt: now.add(const Duration(days: 7)).toUtc(),
              allocationStatus: 'locked',
            ),
          );
        });

        final bloc = ActivityHistoryBloc(
          getActivityHistoryUseCase: mockGetHistory,
          getTransactionDetailUseCase: mockGetDetail,
          exportMonthlyStatementUseCase: mockExportStatement,
        );
        addTearDown(() => bloc.close());

        await tester.pumpWidget(
          MaterialApp(
            home: ActivityHistoryPage(bloc: bloc, clockProvider: () => now),
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('Activity & History'), findsOneWidget);
        expect(find.text('2,450 pts'), findsOneWidget);
        expect(find.text('≈ ₹245.00'), findsOneWidget);
        expect(find.text('3,200 pts'), findsOneWidget);
        expect(find.text('750 pts'), findsOneWidget);
        expect(find.textContaining('Ledger reconciliation note'), findsOneWidget);

        // Split POS badges
        expect(find.text('+120 pts'), findsOneWidget);
        expect(find.text('70 pts Locked'), findsOneWidget);
        expect(find.text('50 pts Available'), findsOneWidget);

        // Tap POS card -> expands allocation breakdown
        await tester.tap(find.text('Counter #1 POS'));
        await _pumpFrames(tester);
        expect(find.text('Points Allocation Breakdown'), findsOneWidget);
        expect(find.text('70 pts'), findsWidgets);

        // Tap Claim card -> expands audit details
        await tester.ensureVisible(find.text('Claim Verified & Redeemed'));
        await tester.tap(find.text('Claim Verified & Redeemed'));
        await _pumpFrames(tester);
        expect(find.text('Claim Audit Details'), findsOneWidget);
        expect(find.text('CLM-8456-012'), findsOneWidget);

        // Open Monthly Statement modal
        await tester.ensureVisible(
          find.text('Download Monthly Statement (PDF / CSV)'),
        );
        await tester.tap(find.text('Download Monthly Statement (PDF / CSV)'));
        await _pumpFrames(tester);

        expect(find.text('Download Monthly Statement'), findsOneWidget);
        expect(find.text('PDF Statement'), findsOneWidget);
        expect(find.text('CSV Ledger'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'navigates from Home bottom nav History tab to ActivityHistoryPage and back via Home tab',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockGetHome = _MockGetHomeDashboardUseCase();
        when(() => mockGetHome(any())).thenAnswer(
          (_) async => Right(
            HomeDashboardEntity(
              customerId: 'u-1',
              fullName: 'Vishnu Kumar',
              email: 'vishnu@example.com',
              mobileNumber: '+919876543210',
              wallet: const WalletSummaryEntity(
                customerCode: 'SHFT-81F6',
                membershipTier: 'Pebble Black Member',
                availablePoints: 2450,
                lockedPoints: 100,
                lifetimeEarnedPoints: 2550,
                lifetimeRedeemedPoints: 0,
                pointsEarnedToday: 15,
                pointsToInrRate: 0.10,
              ),
              lockedAllocations: const [],
              streak: DailyStreakEntity(
                dailyLoginEnabled: true,
                dailyPoints: 15,
                currentStreakDay: 2,
                claimedToday: true,
                daysRemaining: 5,
                cycleDate: '2026-11-18',
                nextResetAt: DateTime.utc(2026, 11, 19, 0, 30),
                justCompletedDay7: false,
                completedStreakPoints: 0,
              ),
              advertisements: const [],
              recentTransactions: const [],
            ),
          ),
        );
        when(() => mockGetHistory(any())).thenAnswer(
          (_) async => Right(
            ActivityHistoryPageEntity(
              summary: buildSummary(),
              filter: ActivityFilter.all,
              limit: 20,
              offset: 0,
              hasMore: false,
              transactions: const [],
            ),
          ),
        );

        final authBloc = buildIdleAuthBloc();
        final homeBloc = HomeBloc(
          getHomeDashboardUseCase: mockGetHome,
          generateClaimQrUseCase: _MockGenerateClaimQrUseCase(),
          trackAdvertisementEventUseCase: _MockTrackAdvertisementEventUseCase(),
        );
        final historyBloc = ActivityHistoryBloc(
          getActivityHistoryUseCase: mockGetHistory,
          getTransactionDetailUseCase: mockGetDetail,
          exportMonthlyStatementUseCase: mockExportStatement,
        );

        final router = GoRouter(
          initialLocation: RoutesNames.home,
          routes: [
            GoRoute(
              path: RoutesNames.home,
              builder: (_, _) => HomePage(homeBloc: homeBloc),
            ),
            GoRoute(
              path: RoutesNames.activityHistory,
              builder: (_, _) => ActivityHistoryPage(bloc: historyBloc),
            ),
          ],
        );

        addTearDown(() async {
          router.dispose();
          await historyBloc.close();
          await homeBloc.close();
          await authBloc.close();
        });

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthenticationBloc>.value(value: authBloc),
              BlocProvider<HomeBloc>.value(value: homeBloc),
              BlocProvider<ActivityHistoryBloc>.value(value: historyBloc),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await _pumpFrames(tester);

        expect(find.text('Hello, Vishnu'), findsOneWidget);

        await tester.tap(find.text('History'));
        await _pumpFrames(tester);

        expect(find.text('Activity & History'), findsOneWidget);
        expect(find.text('No reward transactions recorded yet.'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(ActivityHistoryPage),
            matching: find.text('Home'),
          ),
        );
        await _pumpFrames(tester);
        expect(find.text('Hello, Vishnu'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final viewport in [
      const Size(320, 568),
      const Size(375, 812),
      const Size(430, 932),
    ]) {
      testWidgets(
        'renders cleanly without overflow at ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(viewport);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          when(() => mockGetHistory(any())).thenAnswer(
            (_) async => Right(
              ActivityHistoryPageEntity(
                summary: buildSummary(),
                filter: ActivityFilter.all,
                limit: 20,
                offset: 0,
                hasMore: false,
                transactions: [buildPosTx(), buildClaimTx()],
              ),
            ),
          );

          final bloc = ActivityHistoryBloc(
            getActivityHistoryUseCase: mockGetHistory,
            getTransactionDetailUseCase: mockGetDetail,
            exportMonthlyStatementUseCase: mockExportStatement,
          );
          addTearDown(() => bloc.close());

          await tester.pumpWidget(
            MaterialApp(home: ActivityHistoryPage(bloc: bloc)),
          );
          await _pumpFrames(tester);

          expect(find.text('Activity & History'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'supports filter empty state, pull-to-refresh, and scroll pagination',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var allZeroLoadCount = 0;
        var loadedSecondPage = false;
        when(() => mockGetHistory(any())).thenAnswer((invocation) async {
          final params =
              invocation.positionalArguments.first as GetActivityHistoryParams;
          if (params.filter == ActivityFilter.all && params.offset == 0) {
            allZeroLoadCount++;
          }
          if (params.filter == ActivityFilter.claims) {
            return Right(
              ActivityHistoryPageEntity(
                summary: buildSummary(),
                filter: ActivityFilter.claims,
                limit: 20,
                offset: 0,
                hasMore: false,
                transactions: const [],
              ),
            );
          }
          if (params.offset > 0) {
            loadedSecondPage = true;
            return Right(
              ActivityHistoryPageEntity(
                summary: buildSummary(),
                filter: ActivityFilter.all,
                limit: 20,
                offset: params.offset,
                hasMore: false,
                transactions: [buildClaimTx(id: 'tx-claim-page-2')],
              ),
            );
          }
          return Right(
            ActivityHistoryPageEntity(
              summary: buildSummary(),
              filter: params.filter,
              limit: 20,
              offset: 0,
              hasMore: true,
              transactions: [
                for (int i = 0; i < 8; i++)
                  buildPosTx(
                    id: 'tx-pos-$i',
                    createdAt: DateTime.utc(2026, 11, 18, 9 - i),
                  ),
              ],
            ),
          );
        });

        final bloc = ActivityHistoryBloc(
          getActivityHistoryUseCase: mockGetHistory,
          getTransactionDetailUseCase: mockGetDetail,
          exportMonthlyStatementUseCase: mockExportStatement,
        );
        addTearDown(() => bloc.close());

        await tester.pumpWidget(
          MaterialApp(home: ActivityHistoryPage(bloc: bloc)),
        );
        await _pumpFrames(tester);

        final verticalScrollFinder = find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
        );

        // Scroll to bottom -> triggers infinite scroll pagination.
        await tester.ensureVisible(
          find.text('Download Monthly Statement (PDF / CSV)'),
        );
        await _pumpFrames(tester);
        expect(loadedSecondPage, isTrue);
        expect(find.text('Claim Verified & Redeemed'), findsOneWidget);

        // Scroll back to top (offset 0) and trigger pull-to-refresh.
        tester
            .widget<SingleChildScrollView>(verticalScrollFinder)
            .controller!
            .jumpTo(0);
        await tester.pump();
        await tester.fling(
          find.byType(RefreshIndicator),
          const Offset(0, 400),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await _pumpFrames(tester);
        expect(allZeroLoadCount, greaterThanOrEqualTo(2));

        // Tap Claims (-) filter chip -> empty filter card shown.
        await tester.tap(find.text('Claims (-)'));
        await _pumpFrames(tester);
        expect(
          find.text('No completed claim redemptions recorded yet.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
