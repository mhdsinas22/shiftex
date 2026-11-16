enum AccountApprovalStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  suspended('suspended');

  final String value;
  const AccountApprovalStatus(this.value);

  static AccountApprovalStatus fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'approved':
        return AccountApprovalStatus.approved;
      case 'rejected':
        return AccountApprovalStatus.rejected;
      case 'suspended':
        return AccountApprovalStatus.suspended;
      case 'pending':
      default:
        return AccountApprovalStatus.pending;
    }
  }
}
