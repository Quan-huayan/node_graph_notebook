/// 可释放资源的统一接口。
///
/// 实现了该接口的单例服务，在容器整体销毁或按 owner 清理时
/// 会调用其 dispose 方法释放资源。
abstract interface class Disposable {
  /// 释放资源。
  void dispose();
}
