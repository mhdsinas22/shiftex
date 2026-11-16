import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';

class LogoutUseCase implements UseCase<void, NoParams> {
  final AuthenticationRepository _repository;

  const LogoutUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return _repository.logout();
  }
}
