import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/customer_qr/domain/repositories/customer_qr_repository.dart';

class RevokeCustomerPersonalQrUseCase implements UseCase<bool, NoParams> {
  final CustomerQrRepository _repository;

  const RevokeCustomerPersonalQrUseCase(this._repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) {
    return _repository.revokePersonalQr();
  }
}
