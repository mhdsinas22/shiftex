import 'package:equatable/equatable.dart';

abstract class CustomerQrEvent extends Equatable {
  const CustomerQrEvent();

  @override
  List<Object?> get props => [];
}

class CustomerQrLoadRequested extends CustomerQrEvent {
  final bool forceRegenerate;

  const CustomerQrLoadRequested({this.forceRegenerate = false});

  @override
  List<Object?> get props => [forceRegenerate];
}

class CustomerQrRefreshRequested extends CustomerQrEvent {
  const CustomerQrRefreshRequested();
}

class CustomerQrRevokeRequested extends CustomerQrEvent {
  const CustomerQrRevokeRequested();
}

class CustomerQrExpiryChecked extends CustomerQrEvent {
  final DateTime? now;

  const CustomerQrExpiryChecked({this.now});

  @override
  List<Object?> get props => [now];
}

class CustomerIdCopyRequested extends CustomerQrEvent {
  const CustomerIdCopyRequested();
}

class CustomerQrFeedbackCleared extends CustomerQrEvent {
  const CustomerQrFeedbackCleared();
}
