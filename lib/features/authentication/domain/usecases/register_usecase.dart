import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';

class RegisterParams extends Equatable {
  final String firstName;
  final String lastName;
  final String mobileNumber;
  final String email;
  final String password;

  const RegisterParams({
    required this.firstName,
    required this.lastName,
    required this.mobileNumber,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    mobileNumber,
    email,
    password,
  ];
}

class RegisterUseCase implements UseCase<String, RegisterParams> {
  final AuthenticationRepository _repository;

  const RegisterUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(RegisterParams params) {
    return _repository.register(
      firstName: params.firstName,
      lastName: params.lastName,
      mobileNumber: params.mobileNumber,
      email: params.email,
      password: params.password,
    );
  }
}
