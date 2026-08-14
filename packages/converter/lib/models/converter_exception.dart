/// 转换异常，用于表示转换过程中的错误
class ConverterException implements Exception {
  /// 创建转换异常
  /// 
  /// [message] - 错误信息
  ConverterException(this.message);

  /// 错误信息
  final String message;

  @override
  /// 返回异常的字符串表示
  String toString() => 'ConverterException: $message';
}
