import 'package:equatable/equatable.dart';

abstract class AccountApprovalEvent extends Equatable {
  const AccountApprovalEvent();

  @override
  List<Object?> get props => [];
}

class LoadApprovalStatusRequested extends AccountApprovalEvent {
  const LoadApprovalStatusRequested();
}

class RefreshApprovalStatusRequested extends AccountApprovalEvent {
  const RefreshApprovalStatusRequested();
}
