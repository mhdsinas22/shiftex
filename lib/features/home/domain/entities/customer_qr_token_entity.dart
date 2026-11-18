import 'package:equatable/equatable.dart';

class CustomerQrTokenEntity extends Equatable {
  final String id;
  final String tokenCode;
  final String qrPayload;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  const CustomerQrTokenEntity({
    required this.id,
    required this.tokenCode,
    required this.qrPayload,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  int remainingSeconds(DateTime now) {
    final secs = expiresAt.difference(now).inSeconds;
    return secs < 0 ? 0 : secs;
  }

  @override
  List<Object?> get props => [
    id,
    tokenCode,
    qrPayload,
    status,
    expiresAt,
    createdAt,
  ];
}
