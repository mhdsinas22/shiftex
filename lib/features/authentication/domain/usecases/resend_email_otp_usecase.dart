import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';

class ResendEmailOtpParams extends Equatable {
  final String email;

  const ResendEmailOtpParams({required this.email});

  @override
  List<Object?> get props => [email];
}

class ResendEmailOtpUseCase implements UseCase<void, ResendEmailOtpParams> {
  final AuthenticationRepository _repository;

  const ResendEmailOtpUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(ResendEmailOtpParams params) {
    return _repository.resendEmailOtp(email: params.email);
  }
}
