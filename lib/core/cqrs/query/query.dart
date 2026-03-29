/// Query 基类
///
/// 所有查询操作的基类，代表对系统的只读请求
/// Query 是不可变的（immutable），不会修改系统状态
abstract class Query<T> {
  /// 构造函数
  const Query();
  /// 查询的唯一标识符
  ///
  /// 用于缓存键生成和日志记录
  String get queryId => '${runtimeType}_$hashCode';
}

/// 可缓存的 Query 接口
///
/// 实现此接口的 Query 会被自动缓存
abstract class CacheableQuery<T> extends Query<T> {
  /// 构造函数
  const CacheableQuery();
  /// 缓存有效期
  ///
  /// 如果为 null，使用 QueryBus 的默认缓存时间
  Duration? get cacheTtl => null;

  /// 缓存键
  ///
  /// 默认使用 queryId，可以重写以实现自定义缓存策略
  String get cacheKey => queryId;
}

/// Query Result 类
///
/// 封装查询执行的结果，包含成功/失败状态和数据或错误信息
class QueryResult<T> {
  /// 构造函数
  const QueryResult({
    required this.isSuccess,
    this.data,
    this.error,
    this.stackTrace,
  });

  /// 创建成功结果
  factory QueryResult.success(T data) => QueryResult<T>(
        isSuccess: true,
        data: data,
      );

  /// 创建失败结果
  factory QueryResult.failure(
    String error, [
    StackTrace? stackTrace,
  ]) =>
      QueryResult<T>(
        isSuccess: false,
        error: error,
        stackTrace: stackTrace,
      );

  /// 是否查询成功
  final bool isSuccess;

  /// 查询结果数据（成功时）
  final T? data;

  /// 错误信息（失败时）
  final String? error;

  /// 错误堆栈（失败时，可选）
  final StackTrace? stackTrace;

  /// 获取数据或抛出异常
  ///
  /// 如果查询成功，返回数据；否则抛出包含错误信息的异常
  T get dataOrThrow {
    if (isSuccess && data != null) {
      return data!;
    }
    throw QueryException(error ?? 'Query failed without error message');
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'QueryResult.success($data)';
    }
    return 'QueryResult.failure($error)';
  }
}

/// Query Exception
///
/// 查询失败时抛出的异常
class QueryException implements Exception {
  /// 构造函数
  const QueryException(this.message);

  /// 错误信息
  final String message;

  @override
  String toString() => 'QueryException: $message';
}

/// Query Handler 基类
///
/// 负责处理特定类型的 Query 并返回结果
/// Query Handler 应该是纯粹的计算逻辑，不修改状态
abstract class QueryHandler<T, Q extends Query<T>> {
  /// 处理查询并返回结果
  ///
  /// [query] 要处理的查询对象
  /// 返回查询结果，如果查询失败则包含错误信息
  Future<QueryResult<T>> handle(Q query);
}

/// Query Handler 绑定
///
/// 用于注册 Query 和对应的 Handler
class QueryHandlerBinding<T, Q extends Query<T>> {
  /// 构造函数
  const QueryHandlerBinding({
    required this.queryType,
    required this.handlerFactory,
  });

  /// Query 类型
  final Type queryType;

  /// Query Handler 工厂函数
  final QueryHandler<T, Q> Function() handlerFactory;
}
