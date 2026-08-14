/// 重复注册同一扩展点（同 Type 同 id）时抛出。
class ExtensionPointAlreadyRegisteredException implements Exception {
  /// 构造：扩展点 id 与类型。
  ExtensionPointAlreadyRegisteredException(this.id, this.type);

  /// 扩展点 id。
  final String id;

  /// 扩展点类型。
  final Type type;

  @override
  String toString() =>
      'ExtensionPointAlreadyRegisteredException: 扩展点 "$id"($type) 已注册';
}

/// 向未注册的扩展点添加贡献时抛出（拼写错误保护）。
class ExtensionPointNotRegisteredException implements Exception {
  /// 构造：扩展点 id 与类型。
  ExtensionPointNotRegisteredException(this.id, this.type);

  /// 扩展点 id。
  final String id;

  /// 扩展点类型。
  final Type type;

  @override
  String toString() =>
      'ExtensionPointNotRegisteredException: 扩展点 "$id"($type) 尚未注册';
}
