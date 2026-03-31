import 'logger.dart';

/// 安全回调执行工具类
///
/// 提供带异常处理的回调执行方法，防止回调异常导致应用崩溃
class SafeCallback {
  /// 执行同步回调并返回结果
  ///
  /// [callback] 要执行的回调函数
  /// [onError] 错误处理函数，接收捕获的异常
  /// [fallbackValue] 回调失败或为 null 时返回的默认值
  ///
  /// 返回回调执行结果，失败时返回 fallbackValue
  ///
  /// 示例:
  /// ```dart
  /// final result = SafeCallback.call<String>(
  ///   callback: () => 'hello',
  ///   fallbackValue: 'default',
  /// );
  /// ```
  static T? call<T>({
    dynamic Function()? callback,
    void Function(dynamic error)? onError,
    T? fallbackValue,
  }) {
    if (callback == null) {
      return fallbackValue;
    }

    try {
      final result = callback();
      return result as T?;
    } catch (e) {
      const AppLogger('SafeCallback').warning('Callback failed', error: e);
      onError?.call(e);
      return fallbackValue;
    }
  }

  /// 执行异步回调并返回结果
  ///
  /// [callback] 要执行的异步回调函数
  /// [onError] 错误处理函数，接收捕获的异常
  /// [fallbackValue] 回调失败或为 null 时返回的默认值
  ///
  /// 返回回调执行结果，失败时返回 fallbackValue
  ///
  /// 示例:
  /// ```dart
  /// final result = await SafeCallback.callAsync<String>(
  ///   callback: () async => await fetchData(),
  ///   fallbackValue: 'default',
  /// );
  /// ```
  static Future<T?> callAsync<T>({
    Future<dynamic>? Function()? callback,
    void Function(dynamic error)? onError,
    T? fallbackValue,
  }) async {
    if (callback == null) {
      return fallbackValue;
    }

    try {
      final result = await callback();
      return result as T?;
    } catch (e) {
      const AppLogger('SafeCallback').warning('Async callback failed', error: e);
      onError?.call(e);
      return fallbackValue;
    }
  }

  /// 执行带单个参数的同步回调并返回结果
  ///
  /// [callback] 要执行的回调函数，接受一个参数
  /// [arg] 传递给回调的参数
  /// [onError] 错误处理函数，接收捕获的异常
  /// [fallbackValue] 回调失败或为 null 时返回的默认值
  ///
  /// 返回回调执行结果，失败时返回 fallbackValue
  ///
  /// 示例:
  /// ```dart
  /// final result = SafeCallback.callWithArg<String, int>(
  ///   callback: (x) => 'Value: $x',
  ///   arg: 42,
  ///   fallbackValue: 'default',
  /// );
  /// ```
  static T? callWithArg<T, P>({
    dynamic Function(P arg)? callback,
    required P arg,
    void Function(dynamic error)? onError,
    T? fallbackValue,
  }) {
    if (callback == null) {
      return fallbackValue;
    }

    try {
      final result = callback(arg);
      return result as T?;
    } catch (e) {
      const AppLogger('SafeCallback').warning('Callback with arg failed', error: e);
      onError?.call(e);
      return fallbackValue;
    }
  }

  /// 执行带多个参数的同步回调并返回结果
  ///
  /// [callback] 要执行的回调函数，接受参数列表
  /// [args] 传递给回调的参数列表
  /// [onError] 错误处理函数，接收捕获的异常
  /// [fallbackValue] 回调失败或为 null 时返回的默认值
  ///
  /// 返回回调执行结果，失败时返回 fallbackValue
  ///
  /// 示例:
  /// ```dart
  /// final result = SafeCallback.callWithArgs<String>(
  ///   callback: (args) => 'Args: ${args.join(", ")}',
  ///   args: ['a', 'b', 'c'],
  ///   fallbackValue: 'default',
  /// );
  /// ```
  static T? callWithArgs<T>({
    dynamic Function(List<dynamic> args)? callback,
    required List<dynamic> args,
    void Function(dynamic error)? onError,
    T? fallbackValue,
  }) {
    if (callback == null) {
      return fallbackValue;
    }

    try {
      final result = callback(args);
      return result as T?;
    } catch (e) {
      const AppLogger('SafeCallback').warning('Callback with args failed', error: e);
      onError?.call(e);
      return fallbackValue;
    }
  }

  /// 检查回调是否可执行（非 null）
  ///
  /// [callback] 要检查的回调函数
  ///
  /// 返回 true 如果回调不为 null
  ///
  /// 示例:
  /// ```dart
  /// void Function()? myCallback = () {};
  /// if (SafeCallback.isCallable(myCallback)) {
  ///   myCallback!();
  /// }
  /// ```
  static bool isCallable(dynamic Function()? callback) => callback != null;
}
