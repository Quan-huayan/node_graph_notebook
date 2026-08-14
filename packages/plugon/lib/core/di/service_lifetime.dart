/// 服务实例的生命周期语义（对齐 .NET DI 的 lifetime 概念）。
enum ServiceLifetime {
  /// 首次解析时创建，之后复用同一实例（全局缓存）。
  singleton,

  /// 每次解析都创建新实例，不缓存、不追踪销毁。
  transient,

  /// 每个服务作用域（scope）内单例，scope 销毁时随之销毁。
  scoped,
}
