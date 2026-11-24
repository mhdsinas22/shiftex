import 'package:equatable/equatable.dart';

/// Immutable result of an in-place phone number update on the authenticated
/// customer's existing `public.profiles` record.
class ChangePhoneResultEntity extends Equatable {
  final String userId;
  final String previousPhoneNumber;
  final String updatedPhoneNumber;
  final String displayPhoneNumber;
  final String message;

  const ChangePhoneResultEntity({
    required this.userId,
    required this.previousPhoneNumber,
    required this.updatedPhoneNumber,
    required this.displayPhoneNumber,
    required this.message,
  });

  @override
  List<Object?> get props => [
    userId,
    previousPhoneNumber,
    updatedPhoneNumber,
    displayPhoneNumber,
    message,
  ];
}
