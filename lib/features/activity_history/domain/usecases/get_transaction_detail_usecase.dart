import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/activity_history/domain/entities/activity_transaction_entity.dart';
import 'package:shiftex/features/activity_history/domain/repositories/activity_history_repository.dart';

class GetTransactionDetailParams extends Equatable {
  final String entryId;

  const GetTransactionDetailParams({required this.entryId});

  @override
  List<Object?> get props => [entryId];
}

class GetTransactionDetailUseCase
    implements
        UseCase<ActivityTransactionDetailsEntity, GetTransactionDetailParams> {
  final ActivityHistoryRepository _repository;

  const GetTransactionDetailUseCase(this._repository);

  @override
  Future<Either<Failure, ActivityTransactionDetailsEntity>> call(
    GetTransactionDetailParams params,
  ) {
    return _repository.getTransactionDetail(entryId: params.entryId);
  }
}
