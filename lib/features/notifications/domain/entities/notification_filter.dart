/// Filter chips displayed in the Notifications Center horizontal filter bar.
enum NotificationFilter {
  all,
  unread,
  pointsRewards,
  announcements;

  String get apiValue {
    switch (this) {
      case NotificationFilter.all:
        return 'all';
      case NotificationFilter.unread:
        return 'unread';
      case NotificationFilter.pointsRewards:
        return 'points_rewards';
      case NotificationFilter.announcements:
        return 'announcements';
    }
  }

  String get label {
    switch (this) {
      case NotificationFilter.all:
        return 'All';
      case NotificationFilter.unread:
        return 'Unread';
      case NotificationFilter.pointsRewards:
        return 'Points & Rewards';
      case NotificationFilter.announcements:
        return 'Announcements';
    }
  }

  static NotificationFilter fromApiValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'unread':
        return NotificationFilter.unread;
      case 'points_rewards':
        return NotificationFilter.pointsRewards;
      case 'announcements':
        return NotificationFilter.announcements;
      case 'all':
      default:
        return NotificationFilter.all;
    }
  }
}
