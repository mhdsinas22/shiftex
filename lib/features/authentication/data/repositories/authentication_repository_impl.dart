import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/account_approval/domain/entities/customer_profile_entity.dart';
import 'package:shiftex/features/authentication/data/datasources/authentication_remote_data_source.dart';
import 'package:shiftex/features/authentication/domain/repositories/authentication_repository.dart';

class AuthenticationRepositoryImpl implements AuthenticationRepository {
  final AuthenticationRemoteDataSource _remoteDataSource;

  const AuthenticationRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, String>> register({
    required String firstName,
    required String lastName,
    required String mobileNumber,
    required String email,
    required String password,
  }) async {
    try {
      final registeredEmail = await _remoteDataSource.register(
        firstName: firstName,
        lastName: lastName,
        mobileNumber: mobileNumber,
        email: email,
        password: password,
      );
      return Right(registeredEmail);
    } catch (e) {
      return Left(
        ErrorMapper.mapExceptionToFailure(e, fallbackEmail: email),
      );
    }
  }

  @override
  Future<Either<Failure, CustomerProfileEntity>> verifyEmailOtp({
    required String email,
    required String otpCode,
    String? fullName,
    String? mobileNumber,
  }) async {
    try {
      final profile = await _remoteDataSource.verifyEmailOtp(
        email: email,
        otpCode: otpCode,
        fullName: fullName,
        mobileNumber: mobileNumber,
      );
      return Right(profile);
    } catch (e) {
      return Left(
        ErrorMapper.mapExceptionToFailure(e, fallbackEmail: email),
      );
    }
  }

  @override
  Future<Either<Failure, void>> resendEmailOtp({
    required String email,
  }) async {
    try {
      await _remoteDataSource.resendEmailOtp(email: email);
      return const Right(null);
    } catch (e) {
      return Left(
        ErrorMapper.mapExceptionToFailure(e, fallbackEmail: email),
      );
    }
  }

  @override
  Future<Either<Failure, CustomerProfileEntity>> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      final profile = await _remoteDataSource.login(
        identifier: identifier,
        password: password,
        rememberMe: rememberMe,
      );
      return Right(profile);
    } catch (e) {
      return Left(
        ErrorMapper.mapExceptionToFailure(
          e,
          fallbackEmail: identifier.contains('@') ? identifier.trim() : null,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetOtp({
    required String email,
  }) async {
    try {
      await _remoteDataSource.sendPasswordResetOtp(email: email);
      return const Right(null);
    } catch (e) {
      return Left(
        ErrorMapper.mapExceptionToFailure(e, fallbackEmail: email),
      );
    }
  }

  @override
  Future<Either<Failure, void>> verifyPasswordResetOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      await _remoteDataSource.verifyPasswordResetOtp(
        email: email,
        otpCode: otpCode,
      );
      return const Right(null);
    } catch (e) {
      return Left(
        ErrorMapper.mapExceptionToFailure(e, fallbackEmail: email),
      );
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String newPassword,
  }) async {
    try {
      await _remoteDataSource.resetPassword(newPassword: newPassword);
      return const Right(null);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, CustomerProfileEntity?>>
  getCurrentSessionProfile() async {
    try {
      final profile = await _remoteDataSource.getCurrentSessionProfile();
      return Right(profile);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remoteDataSource.logout();
      return const Right(null);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Stream<String> get authSessionEvents => _remoteDataSource.authSessionEvents;
}
