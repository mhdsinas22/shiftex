import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/core/utils/usecase.dart';
import 'package:shiftex/features/change_password/domain/repositories/change_password_repository.dart';

/// Encapsulates credentials required to change the signed-in user's password.
class ChangePasswordParams extends Equatable {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordParams({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword];

  @override
  bool get stringify => false;

  @override
  String toString() => 'ChangePasswordParams(redacted)';
}

/// Executes password verification and update for the authenticated customer.
class ChangePasswordUseCase implements UseCase<Unit, ChangePasswordParams> {
  final ChangePasswordRepository _repository;

  const ChangePasswordUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(ChangePasswordParams params) {
    return _repository.changePassword(
      currentPassword: params.currentPassword,
      newPassword: params.newPassword,
    );
  }
}
