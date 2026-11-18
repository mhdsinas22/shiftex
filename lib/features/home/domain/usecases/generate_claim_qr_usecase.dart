import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/home/domain/entities/customer_qr_token_entity.dart';
import 'package:shiftex/features/home/domain/repositories/home_repository.dart';

class GenerateClaimQrUseCase
    implements UseCase<CustomerQrTokenEntity, NoParams> {
  final HomeRepository _repository;

  const GenerateClaimQrUseCase(this._repository);

  @override
  Future<Either<Failure, CustomerQrTokenEntity>> call(NoParams params) {
    return _repository.generateClaimQrToken();
  }
}
