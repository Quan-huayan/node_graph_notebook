/// Repository 层异常
///
/// 用于表示数据访问层的错误
class RepositoryException implements Exception {
  /// 创建仓库异常
  ///
  /// [message]: 错误信息
  /// [cause]: 可选的底层错误原因
  const RepositoryException(this.message, [this.cause]);

  /// 错误信息
  final String message;
  
  /// 底层错误原因
  final Object? cause;

  @override
  String toString() =>
      'RepositoryException: $message${cause != null ? ' (caused by $cause)' : ''}';
}
