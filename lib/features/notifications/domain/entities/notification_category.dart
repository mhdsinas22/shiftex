/// Broad notification bucket persisted by Supabase triggers & feeds.
enum NotificationCategory {
  pointsRewards,
  claims,
  announcements,
  account;

  String get apiValue {
    switch (this) {
      case NotificationCategory.pointsRewards:
        return 'points_rewards';
      case NotificationCategory.claims:
        return 'claims';
      case NotificationCategory.announcements:
        return 'announcements';
      case NotificationCategory.account:
        return 'account';
    }
  }

  static NotificationCategory fromString(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'points_rewards':
        return NotificationCategory.pointsRewards;
      case 'claims':
        return NotificationCategory.claims;
      case 'announcements':
        return NotificationCategory.announcements;
      case 'account':
        return NotificationCategory.account;
      default:
        return NotificationCategory.pointsRewards;
    }
  }
}

/// Fine-grained business event types matching database constraints.
enum NotificationType {
  posPointsCredited,
  dailyStreakClaimed,
  streakMilestoneCompleted,
  lockedPointsReleased,
  festivalBonusCredited,
  adminPointAdjustment,
  claimGenerated,
  claimRedeemed,
  claimExpired,
  claimRejected,
  campaignPublished,
  promotionalOffer,
  festivalAnnouncement,
  systemAnnouncement,
  accountApproved,
  accountStatusChanged;

  String get apiValue {
    switch (this) {
      case NotificationType.posPointsCredited:
        return 'pos_points_credited';
      case NotificationType.dailyStreakClaimed:
        return 'daily_streak_claimed';
      case NotificationType.streakMilestoneCompleted:
        return 'streak_milestone_completed';
      case NotificationType.lockedPointsReleased:
        return 'locked_points_released';
      case NotificationType.festivalBonusCredited:
        return 'festival_bonus_credited';
      case NotificationType.adminPointAdjustment:
        return 'admin_point_adjustment';
      case NotificationType.claimGenerated:
        return 'claim_generated';
      case NotificationType.claimRedeemed:
        return 'claim_redeemed';
      case NotificationType.claimExpired:
        return 'claim_expired';
      case NotificationType.claimRejected:
        return 'claim_rejected';
      case NotificationType.campaignPublished:
        return 'campaign_published';
      case NotificationType.promotionalOffer:
        return 'promotional_offer';
      case NotificationType.festivalAnnouncement:
        return 'festival_announcement';
      case NotificationType.systemAnnouncement:
        return 'system_announcement';
      case NotificationType.accountApproved:
        return 'account_approved';
      case NotificationType.accountStatusChanged:
        return 'account_status_changed';
    }
  }

  static NotificationType fromString(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'pos_points_credited':
        return NotificationType.posPointsCredited;
      case 'daily_streak_claimed':
        return NotificationType.dailyStreakClaimed;
      case 'streak_milestone_completed':
        return NotificationType.streakMilestoneCompleted;
      case 'locked_points_released':
        return NotificationType.lockedPointsReleased;
      case 'festival_bonus_credited':
        return NotificationType.festivalBonusCredited;
      case 'admin_point_adjustment':
        return NotificationType.adminPointAdjustment;
      case 'claim_generated':
        return NotificationType.claimGenerated;
      case 'claim_redeemed':
        return NotificationType.claimRedeemed;
      case 'claim_expired':
        return NotificationType.claimExpired;
      case 'claim_rejected':
        return NotificationType.claimRejected;
      case 'campaign_published':
        return NotificationType.campaignPublished;
      case 'promotional_offer':
        return NotificationType.promotionalOffer;
      case 'festival_announcement':
        return NotificationType.festivalAnnouncement;
      case 'system_announcement':
        return NotificationType.systemAnnouncement;
      case 'account_approved':
        return NotificationType.accountApproved;
      case 'account_status_changed':
        return NotificationType.accountStatusChanged;
      default:
        return NotificationType.systemAnnouncement;
    }
  }
}

enum NotificationScrollTarget {
  none,
  wallet,
  streak;

  static NotificationScrollTarget fromString(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'wallet':
        return NotificationScrollTarget.wallet;
      case 'streak':
        return NotificationScrollTarget.streak;
      default:
        return NotificationScrollTarget.none;
    }
  }
}

enum NotificationRealtimeConnectionState {
  disconnected,
  connecting,
  subscribed,
  reconnecting,
  error,
}
