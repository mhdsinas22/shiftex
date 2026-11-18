import 'package:dartz/dartz.dart';
import 'package:shiftex/core/errors/failures.dart';
import 'package:shiftex/features/home/domain/entities/customer_qr_token_entity.dart';
import 'package:shiftex/features/home/domain/entities/home_dashboard_entity.dart';

abstract class HomeRepository {
  Future<Either<Failure, HomeDashboardEntity>> getHomeDashboard({
    bool performDailyCheckIn = true,
    String? sessionId,
  });

  Future<Either<Failure, CustomerQrTokenEntity>> generateClaimQrToken();

  Future<Either<Failure, void>> trackAdvertisementEvent({
    required String advertisementId,
    required String eventType,
    String? sessionId,
  });
}
