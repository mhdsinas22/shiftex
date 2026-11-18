import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/customer_qr/domain/entities/customer_qr_entity.dart';
import 'package:shiftex/features/customer_qr/domain/repositories/customer_qr_repository.dart';

class GetCustomerPersonalQrParams extends Equatable {
  final bool forceRegenerate;

  const GetCustomerPersonalQrParams({this.forceRegenerate = false});

  @override
  List<Object?> get props => [forceRegenerate];
}

class GetCustomerPersonalQrUseCase
    implements UseCase<CustomerQrEntity, GetCustomerPersonalQrParams> {
  final CustomerQrRepository _repository;

  const GetCustomerPersonalQrUseCase(this._repository);

  @override
  Future<Either<Failure, CustomerQrEntity>> call(
    GetCustomerPersonalQrParams params,
  ) {
    return _repository.getCustomerPersonalQr(
      forceRegenerate: params.forceRegenerate,
    );
  }
}
