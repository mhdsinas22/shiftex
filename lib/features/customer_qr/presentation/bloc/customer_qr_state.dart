import 'package:equatable/equatable.dart';
import 'package:shiftex/features/customer_qr/domain/entities/customer_qr_entity.dart';

enum CustomerQrStatus { initial, loading, loaded, refreshing, error }

class CustomerQrState extends Equatable {
  final CustomerQrStatus status;
  final CustomerQrEntity? qrData;
  final String? errorMessage;
  final String? infoMessage;
  final bool isExpired;
  final int feedbackSequence;

  const CustomerQrState({
    this.status = CustomerQrStatus.initial,
    this.qrData,
    this.errorMessage,
    this.infoMessage,
    this.isExpired = false,
    this.feedbackSequence = 0,
  });

  bool get hasData => qrData != null;

  bool get isBusy =>
      status == CustomerQrStatus.loading ||
      status == CustomerQrStatus.refreshing;

  CustomerQrState copyWith({
    CustomerQrStatus? status,
    CustomerQrEntity? qrData,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? infoMessage,
    bool clearInfoMessage = false,
    bool? isExpired,
    int? feedbackSequence,
  }) {
    return CustomerQrState(
      status: status ?? this.status,
      qrData: qrData ?? this.qrData,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
      isExpired: isExpired ?? this.isExpired,
      feedbackSequence: feedbackSequence ?? this.feedbackSequence,
    );
  }

  @override
  List<Object?> get props => [
    status,
    qrData,
    errorMessage,
    infoMessage,
    isExpired,
    feedbackSequence,
  ];
}
