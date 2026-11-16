import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';

class VerifyEmailOtpParams extends Equatable {
  final String email;
  final String otpCode;
  final String? fullName;
  final String? mobileNumber;

  const VerifyEmailOtpParams({
    required this.email,
    required this.otpCode,
    this.fullName,
    this.mobileNumber,
  });

  @override
  List<Object?> get props => [email, otpCode, fullName, mobileNumber];
}

class VerifyEmailOtpUseCase
    implements UseCase<CustomerProfileEntity, VerifyEmailOtpParams> {
  final AuthenticationRepository _repository;

  const VerifyEmailOtpUseCase(this._repository);

  @override
  Future<Either<Failure, CustomerProfileEntity>> call(
    VerifyEmailOtpParams params,
  ) {
    return _repository.verifyEmailOtp(
      email: params.email,
      otpCode: params.otpCode,
      fullName: params.fullName,
      mobileNumber: params.mobileNumber,
    );
  }
}
