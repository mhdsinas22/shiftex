import 'package:equatable/equatable.dart';

class AdvertisementCampaignEntity extends Equatable {
  final String id;
  final String title;
  final String offerDetails;
  final String? imageUrl;
  final int popupDurationSeconds;
  final String frequencyType;
  final int frequencyLimit;
  final DateTime startAt;
  final DateTime endAt;

  const AdvertisementCampaignEntity({
    required this.id,
    required this.title,
    required this.offerDetails,
    this.imageUrl,
    required this.popupDurationSeconds,
    required this.frequencyType,
    required this.frequencyLimit,
    required this.startAt,
    required this.endAt,
  });

  int daysUntilExpiry(DateTime now) {
    final diff = endAt.difference(now).inDays;
    return diff < 1 ? 1 : diff;
  }

  String get promoCode {
    final cleaned = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final prefix =
        cleaned.length >= 4
            ? cleaned.substring(0, 4)
            : cleaned.padRight(4, 'X');
    final suffix =
        id.replaceAll('-', '').length >= 2
            ? id.replaceAll('-', '').substring(0, 2).toUpperCase()
            : '89';
    return 'FEST-$prefix-$suffix';
  }

  @override
  List<Object?> get props => [
    id,
    title,
    offerDetails,
    imageUrl,
    popupDurationSeconds,
    frequencyType,
    frequencyLimit,
    startAt,
    endAt,
  ];
}
