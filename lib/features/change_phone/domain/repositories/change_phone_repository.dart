import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/change_phone/domain/entities/change_phone_result_entity.dart';

/// Contract for directly updating the authenticated customer's registered phone
/// number on their existing `public.profiles` record without creating a new
/// account or modifying their user UUID.
abstract class ChangePhoneRepository {
  Future<Either<Failure, ChangePhoneResultEntity>> changePhoneNumber({
    required String newPhoneNumber,
    String? currentPhoneNumber,
  });
}
