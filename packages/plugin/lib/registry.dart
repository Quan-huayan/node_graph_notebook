/// 所有 Registry 的统一接口。
///
/// 提供标准的增删查操作，所有注册表类实现此接口。
abstract class Registry<T> {
  /// 注册一个条目。
  void register(String id, T item);

  /// 注销一个条目。
  void unregister(String id);

  /// 根据 ID 获取条目，不存在返回 null。
  T? getById(String id);

  /// 获取所有已注册的条目。
  List<T> getAll();

  /// 检查指定 ID 的条目是否存在。
  bool contains(String id);
}
