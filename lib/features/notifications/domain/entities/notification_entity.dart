import 'package:equatable/equatable.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String userId;
  final NotificationCategory category;
  final NotificationType type;
  final String title;
  final String body;
  final int? pointsAmount;
  final double? cashValue;
  final String currencyCode;
  final String? referenceType;
  final String? referenceId;
  final String? destinationRoute;
  final String? badgeLabel;
  final Map<String, dynamic> metadata;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.category,
    required this.type,
    required this.title,
    required this.body,
    this.pointsAmount,
    this.cashValue,
    this.currencyCode = 'INR',
    this.referenceType,
    this.referenceId,
    this.destinationRoute,
    this.badgeLabel,
    this.metadata = const {},
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;
  bool get isUnread => readAt == null;

  NotificationScrollTarget get scrollTarget =>
      NotificationScrollTarget.fromString(
        metadata['scroll_target'] as String?,
      );

  String? get advertisementId {
    final fromMeta = (metadata['advertisement_id'] as String?)?.trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    if (referenceType == 'advertisement' &&
        referenceId != null &&
        referenceId!.trim().isNotEmpty) {
      return referenceId;
    }
    return null;
  }

  String? get campaignOfferDetails {
    final raw = metadata['offer_details'] as String?;
    return (raw != null && raw.trim().isNotEmpty) ? raw.trim() : null;
  }

  String? get campaignImageUrl {
    final raw = metadata['image_url'] as String?;
    return (raw != null && raw.trim().isNotEmpty) ? raw.trim() : null;
  }

  DateTime? get campaignStartAt {
    final raw = metadata['start_at'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  DateTime? get campaignEndAt {
    final raw = metadata['end_at'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  bool get isPositivePointCredit {
    return type == NotificationType.posPointsCredited ||
        type == NotificationType.festivalBonusCredited ||
        type == NotificationType.dailyStreakClaimed ||
        type == NotificationType.streakMilestoneCompleted ||
        type == NotificationType.lockedPointsReleased ||
        (pointsAmount != null && pointsAmount! > 0);
  }

  NotificationEntity copyWith({
    DateTime? readAt,
    bool clearReadAt = false,
    String? title,
    String? body,
    int? pointsAmount,
    double? cashValue,
    String? badgeLabel,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationEntity(
      id: id,
      userId: userId,
      category: category,
      type: type,
      title: title ?? this.title,
      body: body ?? this.body,
      pointsAmount: pointsAmount ?? this.pointsAmount,
      cashValue: cashValue ?? this.cashValue,
      currencyCode: currencyCode,
      referenceType: referenceType,
      referenceId: referenceId,
      destinationRoute: destinationRoute,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      metadata: metadata ?? this.metadata,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        category,
        type,
        title,
        body,
        pointsAmount,
        cashValue,
        currencyCode,
        referenceType,
        referenceId,
        destinationRoute,
        badgeLabel,
        metadata,
        readAt,
        createdAt,
      ];
}

class NotificationCountsEntity extends Equatable {
  final int all;
  final int unread;
  final int pointsRewards;
  final int announcements;

  const NotificationCountsEntity({
    this.all = 0,
    this.unread = 0,
    this.pointsRewards = 0,
    this.announcements = 0,
  });

  int countFor(NotificationFilter filter) {
    switch (filter) {
      case NotificationFilter.all:
        return all;
      case NotificationFilter.unread:
        return unread;
      case NotificationFilter.pointsRewards:
        return pointsRewards;
      case NotificationFilter.announcements:
        return announcements;
    }
  }

  NotificationCountsEntity copyWith({
    int? all,
    int? unread,
    int? pointsRewards,
    int? announcements,
  }) {
    return NotificationCountsEntity(
      all: all ?? this.all,
      unread: unread ?? this.unread,
      pointsRewards: pointsRewards ?? this.pointsRewards,
      announcements: announcements ?? this.announcements,
    );
  }

  @override
  List<Object?> get props => [all, unread, pointsRewards, announcements];
}

class NotificationPageEntity extends Equatable {
  final NotificationFilter filter;
  final int limit;
  final int offset;
  final bool hasMore;
  final NotificationCountsEntity counts;
  final List<NotificationEntity> notifications;
  final bool isFromCache;

  const NotificationPageEntity({
    required this.filter,
    required this.limit,
    required this.offset,
    required this.hasMore,
    required this.counts,
    required this.notifications,
    this.isFromCache = false,
  });

  @override
  List<Object?> get props => [
        filter,
        limit,
        offset,
        hasMore,
        counts,
        notifications,
        isFromCache,
      ];
}

class MarkNotificationReadResultEntity extends Equatable {
  final String id;
  final DateTime readAt;
  final int unreadCount;

  const MarkNotificationReadResultEntity({
    required this.id,
    required this.readAt,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [id, readAt, unreadCount];
}

class MarkAllNotificationsReadResultEntity extends Equatable {
  final int updatedCount;
  final int unreadCount;
  final DateTime readAt;

  const MarkAllNotificationsReadResultEntity({
    required this.updatedCount,
    required this.unreadCount,
    required this.readAt,
  });

  @override
  List<Object?> get props => [updatedCount, unreadCount, readAt];
}

enum NotificationRealtimeEventType { insert, update, delete }

class NotificationRealtimeEvent extends Equatable {
  final NotificationRealtimeEventType eventType;
  final NotificationEntity? notification;
  final String? deletedId;

  const NotificationRealtimeEvent({
    required this.eventType,
    this.notification,
    this.deletedId,
  });

  @override
  List<Object?> get props => [eventType, notification, deletedId];
}
