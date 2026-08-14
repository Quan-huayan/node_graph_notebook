import '../di/service_collection.dart';
import '../extensions/extension_registry.dart';
import 'plugin_context.dart';
import 'plugin_metadata.dart';

/// 插件基类（纯 Dart，零 Flutter 依赖）。
///
/// 插件通过四个声明式入口暴露能力：
/// - [registerServices]：向容器注册服务（收到 owned 视图，自动标记 owner）
/// - [registerExtensions]：注册扩展点与贡献（Flowing UI 的 Hook 体系在此之上构建）
///
/// 生命周期回调由 PluginManager 按固定顺序驱动：
/// onLoad →（启用时）onEnable →（卸载时）onDisable → onUnload。
abstract class Plugin {
  /// const 子类化支持。
  const Plugin();

  /// 插件元数据。
  PluginMetadata get metadata;

  /// 注册服务；[services] 是已盖章的 owned 视图，注册自动归属本插件。
  void registerServices(ServiceCollection services) {}

  /// 注册扩展点与贡献；[registry] 为全局扩展注册表。
  void registerExtensions(ExtensionRegistry registry) {}

  /// 加载完成（服务与扩展已注册）后调用；可在此访问依赖服务。
  Future<void> onLoad(PluginContext context) async {}

  /// 启用时调用（依赖已启用之后）。
  Future<void> onEnable() async {}

  /// 停用/卸载时调用。
  Future<void> onDisable() async {}

  /// 卸载前调用（服务与扩展清理之前）。
  Future<void> onUnload() async {}
}
