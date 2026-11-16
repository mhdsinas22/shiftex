import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';

class ForgotPasswordParams extends Equatable {
  final String email;

  const ForgotPasswordParams({required this.email});

  @override
  List<Object?> get props => [email];
}

class ForgotPasswordUseCase implements UseCase<void, ForgotPasswordParams> {
  final AuthenticationRepository _repository;

  const ForgotPasswordUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(ForgotPasswordParams params) {
    return _repository.sendPasswordResetOtp(email: params.email);
  }
}
