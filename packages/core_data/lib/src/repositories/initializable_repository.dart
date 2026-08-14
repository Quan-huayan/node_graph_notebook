/// 可初始化仓库混入
///
/// 提供仓库初始化接口，用于需要异步初始化的仓库实现
mixin InitializableRepository {
  /// 初始化仓库
  Future<void> init();
}
