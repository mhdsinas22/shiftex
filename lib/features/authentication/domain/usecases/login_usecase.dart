import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';

class LoginParams extends Equatable {
  final String identifier;
  final String password;
  final bool rememberMe;

  const LoginParams({
    required this.identifier,
    required this.password,
    this.rememberMe = true,
  });

  @override
  List<Object?> get props => [identifier, password, rememberMe];
}

class LoginUseCase implements UseCase<CustomerProfileEntity, LoginParams> {
  final AuthenticationRepository _repository;

  const LoginUseCase(this._repository);

  @override
  Future<Either<Failure, CustomerProfileEntity>> call(LoginParams params) {
    return _repository.login(
      identifier: params.identifier,
      password: params.password,
      rememberMe: params.rememberMe,
    );
  }
}
