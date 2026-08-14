import 'package:flutter_bloc/flutter_bloc.dart';

import 'hooks/hook_base.dart';
import 'plugin_context.dart';
import 'plugin_metadata.dart';
import 'service_descriptor.dart';

/// Plugin 抽象基类。
///
/// 所有插件必须继承此类，实现 [metadata]。
/// 可选实现 [registerServices], [registerBlocs], [registerHooks]。
///
/// ```dart
/// class MyPlugin extends Plugin {
///   @override
///   PluginMetadata get metadata => const PluginMetadata(
///     id: 'com.example.my_plugin',
///     name: 'My Plugin',
///     version: '1.0.0',
///   );
///
///   @override
///   List<ServiceRegistration> registerServices() => [
///     ServiceRegistration.singleton(() => MyService()),
///   ];
/// }
/// ```
abstract class Plugin {
  /// 插件元数据。
  PluginMetadata get metadata;

  /// 注册服务。返回 [ServiceRegistration] 列表。
  ///
  /// PluginManager 会在 onLoad 之前调用此方法，
  /// 将服务注册到 ServiceRegistry。
  List<ServiceRegistration> registerServices() => [];

  /// 注册 Bloc。返回 BlocProvider 列表。
  ///
  /// 这些 BlocProvider 会被加入 Provider Tree。
  List<BlocProvider> registerBlocs() => [];

  /// 注册 Hook。返回 Hook 工厂列表。
  List<HookFactory> registerHooks() => [];

  /// 插件加载时调用（仅一次）。
  /// 适合执行初始化逻辑、注册命令处理器等。
  Future<void> onLoad(PluginContext context) async {}

  /// 插件启用时调用（可多次：禁用后重新启用）。
  Future<void> onEnable() async {}

  /// 插件禁用时调用（可多次）。
  Future<void> onDisable() async {}

  /// 插件卸载时调用（仅一次）。
  /// 适合释放资源。
  Future<void> onUnload() async {}
}
