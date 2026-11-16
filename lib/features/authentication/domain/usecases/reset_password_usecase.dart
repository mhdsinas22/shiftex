import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';

class ResetPasswordParams extends Equatable {
  final String newPassword;

  const ResetPasswordParams({required this.newPassword});

  @override
  List<Object?> get props => [newPassword];
}

class ResetPasswordUseCase implements UseCase<void, ResetPasswordParams> {
  final AuthenticationRepository _repository;

  const ResetPasswordUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(ResetPasswordParams params) {
    return _repository.resetPassword(newPassword: params.newPassword);
  }
}
