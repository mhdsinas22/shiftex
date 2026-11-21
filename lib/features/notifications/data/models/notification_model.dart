import 'package:shiftex/features/notifications/domain/entities/notification_category.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_entity.dart';
import 'package:shiftex/features/notifications/domain/entities/notification_filter.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.category,
    required super.type,
    required super.title,
    required super.body,
    super.pointsAmount,
    super.cashValue,
    super.currencyCode,
    super.referenceType,
    super.referenceId,
    super.destinationRoute,
    super.badgeLabel,
    super.metadata,
    super.readAt,
    required super.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points_amount'];
    final rawCash = json['cash_value'];
    final rawMeta = json['metadata'];
    return NotificationModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      category: NotificationCategory.fromString(json['category'] as String?),
      type: NotificationType.fromString(json['notification_type'] as String?),
      title: (json['title'] as String?)?.trim() ?? '',
      body: (json['body'] as String?)?.trim() ?? '',
      pointsAmount: rawPoints is num ? rawPoints.toInt() : null,
      cashValue: rawCash is num
          ? rawCash.toDouble()
          : (rawCash is String ? double.tryParse(rawCash) : null),
      currencyCode: (json['currency_code'] as String?)?.trim().isNotEmpty == true
          ? (json['currency_code'] as String).trim()
          : 'INR',
      referenceType: (json['reference_type'] as String?)?.trim(),
      referenceId: (json['reference_id'] as String?)?.trim(),
      destinationRoute: (json['destination_route'] as String?)?.trim(),
      badgeLabel: (json['badge_label'] as String?)?.trim(),
      metadata: rawMeta is Map
          ? Map<String, dynamic>.from(rawMeta)
          : const <String, dynamic>{},
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }

  factory NotificationModel.fromEntity(NotificationEntity entity) {
    return NotificationModel(
      id: entity.id,
      userId: entity.userId,
      category: entity.category,
      type: entity.type,
      title: entity.title,
      body: entity.body,
      pointsAmount: entity.pointsAmount,
      cashValue: entity.cashValue,
      currencyCode: entity.currencyCode,
      referenceType: entity.referenceType,
      referenceId: entity.referenceId,
      destinationRoute: entity.destinationRoute,
      badgeLabel: entity.badgeLabel,
      metadata: entity.metadata,
      readAt: entity.readAt,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': category.apiValue,
      'notification_type': type.apiValue,
      'title': title,
      'body': body,
      'points_amount': pointsAmount,
      'cash_value': cashValue,
      'currency_code': currencyCode,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'destination_route': destinationRoute,
      'badge_label': badgeLabel,
      'metadata': metadata,
      'read_at': readAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class NotificationCountsModel extends NotificationCountsEntity {
  const NotificationCountsModel({
    super.all,
    super.unread,
    super.pointsRewards,
    super.announcements,
  });

  factory NotificationCountsModel.fromJson(Map<String, dynamic> json) {
    return NotificationCountsModel(
      all: (json['all'] as num?)?.toInt() ?? 0,
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      pointsRewards: (json['points_rewards'] as num?)?.toInt() ?? 0,
      announcements: (json['announcements'] as num?)?.toInt() ?? 0,
    );
  }

  factory NotificationCountsModel.fromEntity(NotificationCountsEntity entity) {
    return NotificationCountsModel(
      all: entity.all,
      unread: entity.unread,
      pointsRewards: entity.pointsRewards,
      announcements: entity.announcements,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'all': all,
      'unread': unread,
      'points_rewards': pointsRewards,
      'announcements': announcements,
    };
  }
}

class NotificationPageModel extends NotificationPageEntity {
  const NotificationPageModel({
    required super.filter,
    required super.limit,
    required super.offset,
    required super.hasMore,
    required super.counts,
    required super.notifications,
    super.isFromCache,
  });

  factory NotificationPageModel.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    final countsJson = json['counts'] is Map
        ? Map<String, dynamic>.from(json['counts'] as Map)
        : const <String, dynamic>{};
    final rawList = json['notifications'] as List<dynamic>? ?? const [];
    final items = rawList
        .whereType<Map>()
        .map(
          (row) => NotificationModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();

    return NotificationPageModel(
      filter: NotificationFilter.fromApiValue(json['filter'] as String?),
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      hasMore: (json['has_more'] as bool?) ?? false,
      counts: NotificationCountsModel.fromJson(countsJson),
      notifications: items,
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filter': filter.apiValue,
      'limit': limit,
      'offset': offset,
      'has_more': hasMore,
      'counts': NotificationCountsModel.fromEntity(counts).toJson(),
      'notifications': notifications
          .map((item) => NotificationModel.fromEntity(item).toJson())
          .toList(),
    };
  }
}

class MarkNotificationReadResultModel extends MarkNotificationReadResultEntity {
  const MarkNotificationReadResultModel({
    required super.id,
    required super.readAt,
    required super.unreadCount,
  });

  factory MarkNotificationReadResultModel.fromJson(Map<String, dynamic> json) {
    return MarkNotificationReadResultModel(
      id: (json['id'] ?? '').toString(),
      readAt: json['read_at'] != null
          ? (DateTime.tryParse(json['read_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class MarkAllNotificationsReadResultModel
    extends MarkAllNotificationsReadResultEntity {
  const MarkAllNotificationsReadResultModel({
    required super.updatedCount,
    required super.unreadCount,
    required super.readAt,
  });

  factory MarkAllNotificationsReadResultModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return MarkAllNotificationsReadResultModel(
      updatedCount: (json['updated_count'] as num?)?.toInt() ?? 0,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      readAt: json['read_at'] != null
          ? (DateTime.tryParse(json['read_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }
}
