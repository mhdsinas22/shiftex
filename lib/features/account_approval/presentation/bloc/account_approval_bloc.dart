import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/account_approval/domain/usecases/get_approval_status_usecase.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_event.dart';
import 'package:shiftex/features/account_approval/presentation/bloc/account_approval_state.dart';

class AccountApprovalBloc
    extends Bloc<AccountApprovalEvent, AccountApprovalState> {
  final GetApprovalStatusUseCase _getApprovalStatusUseCase;

  AccountApprovalBloc({
    required GetApprovalStatusUseCase getApprovalStatusUseCase,
  }) : _getApprovalStatusUseCase = getApprovalStatusUseCase,
       super(const AccountApprovalInitial()) {
    on<LoadApprovalStatusRequested>(_onFetchApprovalStatus);
    on<RefreshApprovalStatusRequested>(_onFetchApprovalStatus);
  }

  Future<void> _onFetchApprovalStatus(
    AccountApprovalEvent event,
    Emitter<AccountApprovalState> emit,
  ) async {
    if (state is AccountApprovalLoading) return;
    final previousProfile = state.profile;
    emit(AccountApprovalLoading(profile: previousProfile));

    final result = await _getApprovalStatusUseCase(const NoParams());
    result.fold(
      (failure) => emit(
        AccountApprovalError(
          failure: failure,
          profile: previousProfile,
        ),
      ),
      (profile) => emit(AccountApprovalLoaded(profile)),
    );
  }
}
