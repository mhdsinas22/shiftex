class AppAuthException implements Exception {
  final String message;
  final String code;
  final String? email;
  final String? reason;

  const AppAuthException(
    this.message, {
    this.code = 'auth_exception',
    this.email,
    this.reason,
  });

  @override
  String toString() => 'AppAuthException($code): $message';
}
