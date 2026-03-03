/// 转换异常
class ConverterException implements Exception {
  ConverterException(this.message);

  final String message;

  @override
  String toString() => 'ConverterException: $message';
}