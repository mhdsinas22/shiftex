import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/error_mapper.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/home/data/datasources/home_remote_data_source.dart';
import 'package:shiftex/features/home/domain/entities/customer_qr_token_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';
import 'package:shiftex/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;

  const HomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, HomeDashboardEntity>> getHomeDashboard({
    bool performDailyCheckIn = true,
    String? sessionId,
  }) async {
    try {
      final dashboard = await _remoteDataSource.getHomeDashboard(
        performDailyCheckIn: performDailyCheckIn,
        sessionId: sessionId,
      );
      return Right(dashboard);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, CustomerQrTokenEntity>> generateClaimQrToken() async {
    try {
      final token = await _remoteDataSource.generateClaimQrToken();
      return Right(token);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, void>> trackAdvertisementEvent({
    required String advertisementId,
    required String eventType,
    String? sessionId,
  }) async {
    try {
      await _remoteDataSource.trackAdvertisementEvent(
        advertisementId: advertisementId,
        eventType: eventType,
        sessionId: sessionId,
      );
      return const Right(null);
    } catch (e) {
      return Left(ErrorMapper.mapExceptionToFailure(e));
    }
  }
}
