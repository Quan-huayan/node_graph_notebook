/// Repository 层异常
class RepositoryException implements Exception {
  const RepositoryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'RepositoryException: $message${cause != null ? ' (caused by $cause)' : ''}';
}
