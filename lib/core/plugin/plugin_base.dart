import 'plugin_metadata.dart';
import 'plugin_context.dart';

/// 插件基础接口
///
/// 所有插件必须实现此接口
///
/// 插件生命周期：
/// 1. onLoad(context) - 插件加载时调用，执行初始化
/// 2. onEnable() - 插件启用时调用，激活功能
/// 3. onDisable() - 插件禁用时调用，停用功能
/// 4. onUnload() - 插件卸载时调用，清理资源
///
/// 使用示例：
/// ```dart
/// class MyPlugin extends Plugin {
///   @override
///   PluginMetadata get metadata => PluginMetadata(
///     id: 'com.example.myPlugin',
///     name: 'My Plugin',
///     version: '1.0.0',
///   );
///
///   @override
///   Future<void> onLoad(PluginContext context) async {
///     // 初始化插件
///     context.info('Plugin loaded');
///   }
///
///   @override
///   Future<void> onEnable() async {
///     // 启用功能
///   }
///
///   @override
///   Future<void> onDisable() async {
///     // 禁用功能
///   }
///
///   @override
///   Future<void> onUnload() async {
///     // 清理资源
///   }
/// }
/// ```
abstract class Plugin {
  /// 插件元数据
  ///
  /// 必须实现，返回插件的元数据信息
  PluginMetadata get metadata;

  /// 插件加载
  ///
  /// 在插件加载到系统时调用，此时插件还未启用。
  /// 使用此方法执行轻量级初始化，如注册事件监听器。
  ///
  /// [context] 插件上下文，提供受限的系统 API 访问
  ///
  /// 注意：
  /// - 不要在此方法中执行耗时操作
  /// - 此时插件功能还未激活，用户不能使用插件功能
  /// - 如果抛出异常，插件将被标记为加载失败
  Future<void> onLoad(PluginContext context);

  /// 插件启用
  ///
  /// 在插件被启用时调用。
  /// 使用此方法激活插件功能，如注册 UI 元素、启动后台任务。
  ///
  /// 注意：
  /// - 只有在插件成功加载后才会调用
  /// - 如果抛出异常，插件将被标记为启用失败
  /// - 此方法可能被多次调用（禁用后再启用）
  Future<void> onEnable();

  /// 插件禁用
  ///
  /// 在插件被禁用时调用。
  /// 使用此方法停用插件功能，如注销 UI 元素、停止后台任务。
  ///
  /// 注意：
  /// - 此方法应该与 onEnable 对称
  /// - 如果抛出异常，插件状态可能不一致
  /// - 此方法可能被多次调用（启用后再禁用）
  Future<void> onDisable();

  /// 插件卸载
  ///
  /// 在插件从系统中移除时调用。
  /// 使用此方法释放所有资源，如取消事件监听、关闭文件句柄。
  ///
  /// 注意：
  /// - 如果插件当前是启用状态，会先调用 onDisable
  /// - 卸载后插件不能再被启用
  /// - 即使抛出异常，插件也会被移除
  Future<void> onUnload();

  /// 获取插件状态
  ///
  /// 由插件管理器维护，插件不应直接修改
  PluginState get state;

  /// 设置插件状态
  ///
  /// 仅由插件管理器调用
  @internal
  set state(PluginState newState);

  /// 检查插件是否已加载
  bool get isLoaded => state == PluginState.loaded ||
      state == PluginState.enabled ||
      state == PluginState.disabled;

  /// 检查插件是否已启用
  bool get isEnabled => state == PluginState.enabled;

  @override
  String toString() => 'Plugin(${metadata.id}, version: ${metadata.version})';
}

/// internal 注解
///
/// 用于标记仅由插件系统内部使用的成员
///
/// 这些 API 仅由插件管理器内部使用，插件不应直接调用
class _InternalAnnotation {
  const _InternalAnnotation();
}

/// internal 注解常量
const internal = _InternalAnnotation();
