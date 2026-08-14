/// 扩展点的类型化身份对象。
///
/// 注册表以 `(Type, id)` 为键：同 id 不同泛型类型是不同扩展点。
/// const 构造保证同一写法指向同一身份。
class ExtensionPoint<T> {
  /// 构造：const 身份对象（id 在类型域内唯一）。
  const ExtensionPoint(this.id, {this.name = '', this.description = ''});

  /// 扩展点 id（在 [Type] 域内唯一）。
  final String id;

  /// 展示名。
  final String name;

  /// 描述。
  final String description;
}
