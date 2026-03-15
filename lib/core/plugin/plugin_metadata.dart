/// 插件元数据
///
/// 包含插件的基本信息和配置
class PluginMetadata {
  const PluginMetadata({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.author,
    this.homepage,
    this.dependencies = const [],
    this.minimumAppVersion = '1.0.0',
    this.enabledByDefault = true,
  });

  /// 插件唯一标识符
  ///
  /// 格式：反向域名表示法，如 'com.example.myPlugin'
  final String id;

  /// 插件名称
  final String name;

  /// 插件版本（语义化版本）
  ///
  /// 格式：major.minor.patch，如 '1.2.3'
  final String version;

  /// 插件描述
  final String? description;

  /// 插件作者
  final String? author;

  /// 插件主页 URL
  final String? homepage;

  /// 依赖的其他插件 ID 列表
  ///
  /// 插件管理器会确保这些依赖在加载此插件前已加载
  final List<String> dependencies;

  /// 最低应用版本要求
  ///
  /// 插件管理器会检查应用版本是否满足要求
  final String minimumAppVersion;

  /// 是否默认启用
  ///
  /// true：安装后自动启用
  /// false：需要手动启用
  final bool enabledByDefault;

  /// 检查版本兼容性
  ///
  /// [appVersion] 当前应用版本
  /// 返回 true 如果兼容
  bool isCompatibleWith(String appVersion) {
    final minVersion = minimumAppVersion;
    // 简单的版本比较（仅支持数字版本）
    final appParts = appVersion.split('.').map(int.parse).toList();
    final minParts = minVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < minParts.length; i++) {
      if (i >= appParts.length) return false;
      if (appParts[i] > minParts[i]) return true;
      if (appParts[i] < minParts[i]) return false;
    }

    return true;
  }

  @override
  String toString() {
    return 'PluginMetadata(id: $id, name: $name, version: $version)';
  }
}

/// 插件类型
///
/// 用于区分不同类型的插件
enum PluginType {
  /// 命令中间件插件
  /// 拦截和处理命令
  commandMiddleware,

  /// UI Hook 插件
  /// 扩展 UI 功能
  uiHook,

  /// 渲染器插件
  /// 自定义节点渲染器
  renderer,

  /// 数据源插件
  /// 提供数据导入/导出功能
  dataSource,

  /// 主题插件
  /// 提供自定义主题
  theme,

  /// 语言包插件
  /// 提供多语言支持
  language,

  /// 综合插件
  /// 包含多种功能
  composite,
}

/// 插件权限
///
/// 定义插件可能需要的权限
enum PluginPermission {
  /// 读取节点数据
  readNodes,

  /// 写入节点数据
  writeNodes,

  /// 读取图数据
  readGraphs,

  /// 修改图数据
  modifyGraphs,

  /// 访问文件系统
  accessFileSystem,

  /// 网络访问
  networkAccess,

  /// AI 服务访问
  aiAccess,

  /// 修改 UI
  modifyUI,

  /// 执行命令
  executeCommands,

  /// 访问 EventBus
  accessEventBus,
}

/// 插件状态
enum PluginState {
  /// 未加载
  unloaded,

  /// 已加载（onLoad 已调用）
  loaded,

  /// 已启用（onEnable 已调用）
  enabled,

  /// 已禁用（onDisable 已调用）
  disabled,

  /// 加载失败
  loadFailed,

  /// 启用失败
  enableFailed,
}

/// 插件依赖项
class PluginDependency {
  const PluginDependency({
    required this.pluginId,
    this.minimumVersion,
    this.maximumVersion,
  });

  /// 依赖的插件 ID
  final String pluginId;

  /// 最低版本要求
  final String? minimumVersion;

  /// 最高版本限制
  final String? maximumVersion;

  /// 检查版本是否满足依赖要求
  ///
  /// [version] 要检查的版本
  bool isSatisfiedBy(String version) {
    if (minimumVersion != null) {
      // 简单的版本检查
      final minParts = minimumVersion!.split('.').map(int.parse).toList();
      final verParts = version.split('.').map(int.parse).toList();

      for (int i = 0; i < minParts.length; i++) {
        if (i >= verParts.length) return false;
        if (verParts[i] < minParts[i]) return false;
      }
    }

    if (maximumVersion != null) {
      final maxParts = maximumVersion!.split('.').map(int.parse).toList();
      final verParts = version.split('.').map(int.parse).toList();

      for (int i = 0; i < maxParts.length; i++) {
        if (i >= verParts.length) return false;
        if (verParts[i] > maxParts[i]) return false;
      }
    }

    return true;
  }
}
