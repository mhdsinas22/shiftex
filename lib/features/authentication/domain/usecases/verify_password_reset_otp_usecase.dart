import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';

class VerifyPasswordResetOtpParams extends Equatable {
  final String email;
  final String otpCode;

  const VerifyPasswordResetOtpParams({
    required this.email,
    required this.otpCode,
  });

  @override
  List<Object?> get props => [email, otpCode];
}

class VerifyPasswordResetOtpUseCase
    implements UseCase<void, VerifyPasswordResetOtpParams> {
  final AuthenticationRepository _repository;

  const VerifyPasswordResetOtpUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(VerifyPasswordResetOtpParams params) {
    return _repository.verifyPasswordResetOtp(
      email: params.email,
      otpCode: params.otpCode,
    );
  }
}
