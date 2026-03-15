/// 依赖注入容器
///
/// 负责管理和提供依赖项
class DependencyContainer {
  /// 依赖映射
  ///
  /// Key: 依赖类型
  /// Value: 依赖实例
  final Map<Type, dynamic> _dependencies = {};
  
  /// 依赖工厂映射
  ///
  /// Key: 依赖类型
  /// Value: 依赖工厂函数
  final Map<Type, Function(DependencyContainer)> _factories = {};
  
  /// 注册依赖
  ///
  /// [dependency] 依赖实例
  void register<T>(T dependency) {
    _dependencies[T] = dependency;
  }
  
  /// 注册依赖工厂
  ///
  /// [factory] 依赖工厂函数
  void registerFactory<T>(Function(DependencyContainer) factory) {
    _factories[T] = factory;
  }
  
  /// 获取依赖
  ///
  /// 返回依赖实例，如果未找到则抛出异常
  T get<T>() {
    if (_dependencies.containsKey(T)) {
      return _dependencies[T] as T;
    }
    
    if (_factories.containsKey(T)) {
      final dependency = _factories[T]!(this);
      _dependencies[T] = dependency;
      return dependency as T;
    }
    
    throw DependencyNotFoundException(T);
  }
  
  /// 检查是否包含指定类型的依赖
  ///
  /// [T] 依赖类型
  bool contains<T>() {
    return _dependencies.containsKey(T) || _factories.containsKey(T);
  }
  
  /// 注销依赖
  ///
  /// [T] 依赖类型
  void unregister<T>() {
    _dependencies.remove(T);
    _factories.remove(T);
  }
  
  /// 清空所有依赖
  void clear() {
    _dependencies.clear();
    _factories.clear();
  }
}

/// 依赖未找到异常
class DependencyNotFoundException implements Exception {
  /// 构造函数
  const DependencyNotFoundException(this.type);
  
  /// 依赖类型
  final Type type;
  
  @override
  String toString() => 'DependencyNotFoundException: $type';
}
