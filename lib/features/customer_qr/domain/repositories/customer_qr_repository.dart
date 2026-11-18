import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/customer_qr/domain/entities/customer_qr_entity.dart';

abstract class CustomerQrRepository {
  Future<Either<Failure, CustomerQrEntity>> getCustomerPersonalQr({
    bool forceRegenerate = false,
  });

  Future<Either<Failure, bool>> revokePersonalQr();
}
