/// 标准元数据键定义
///
/// 定义节点和引用的标准元数据键，确保跨插件的一致性。
/// 所有插件应使用这些标准键，或使用 `pluginPrefix` 前缀定义自己的键。
///
/// 使用示例：
/// ```dart
/// // 设置节点类型
/// node.metadata[StandardMetadata.nodeType] = 'concept';
///
/// // 设置文件夹标记
/// node.metadata[StandardMetadata.isFolder] = true;
///
/// // 插件自定义元数据
/// node.metadata['${StandardMetadata.pluginPrefix}myPlugin.customField'] = 'value';
/// ```
class StandardMetadata {
  /// 私有构造函数，防止实例化
  StandardMetadata._();

  // ==================== 节点类型 ====================

  /// 节点类型标识
  ///
  /// 标准值：'concept', 'content', 'folder', 'ai_generated'
  static const String nodeType = 'nodeType';

  /// 文件夹标记
  ///
  /// 布尔值，true 表示该节点是文件夹
  static const String isFolder = 'isFolder';

  /// AI 生成标记
  ///
  /// 布尔值，true 表示该节点由 AI 生成
  static const String isAI = 'isAI';

  // ==================== UI 属性 ====================

  /// 图标标识
  ///
  /// 字符串值，指定节点显示的图标
  static const String icon = 'icon';

  /// 颜色标识
  ///
  /// 十六进制颜色字符串（如 '#FF0000'）或命名颜色
  static const String color = 'color';

  /// 展开状态
  ///
  /// 布尔值，用于文件夹节点的展开/折叠状态
  static const String expanded = 'expanded';

  /// 可见性
  ///
  /// 布尔值，控制节点是否可见
  static const String visible = 'visible';

  /// 锁定状态
  ///
  /// 布尔值，true 表示节点被锁定（不可编辑）
  static const String locked = 'locked';

  // ==================== 内容属性 ====================

  /// 摘要
  ///
  /// 字符串值，节点内容的简短摘要
  static const String summary = 'summary';

  /// 标签列表
  ///
  /// 列表值，节点的标签/关键词
  static const String tags = 'tags';

  /// 优先级
  ///
  /// 数字值（0-10），节点的重要性/优先级
  static const String priority = 'priority';

  // ==================== AI 相关属性 ====================

  /// AI 分数
  ///
  /// 数字值（0.0-1.0），AI 分析的置信度或相关性分数
  static const String aiScore = 'aiScore';

  /// AI 分析结果
  ///
  /// Map 值，包含 AI 分析的详细信息
  static const String aiAnalysis = 'aiAnalysis';

  // ==================== 时间戳 ====================

  /// 创建时间
  ///
  /// DateTime 字符串，节点创建时间（如果与 Node.createdAt 不同）
  static const String createdAt = 'createdAt';

  /// 更新时间
  ///
  /// DateTime 字符串，节点最后更新时间（如果与 Node.updatedAt 不同）
  static const String updatedAt = 'updatedAt';

  /// 访问时间
  ///
  /// DateTime 字符串，节点最后访问时间
  static const String accessedAt = 'accessedAt';

  // ==================== 版本控制 ====================

  /// 版本号
  ///
  /// 字符串值，节点的版本号
  static const String version = 'version';

  /// 作者
  ///
  /// 字符串值，节点创建者
  static const String author = 'author';

  // ==================== 插件元数据 ====================

  /// 插件元数据前缀
  ///
  /// 所有插件应使用此前缀来定义自己的元数据键，避免冲突。
  /// 示例：'plugin.myPlugin.customField'
  static const String pluginPrefix = 'plugin.';

  /// 创建插件元数据键
  ///
  /// [pluginName] 插件名称
  /// [key] 元数据键名
  ///
  /// 返回格式：'plugin.{pluginName}.{key}'
  ///
  /// 示例：
  /// ```dart
  /// final key = StandardMetadata.pluginKey('myPlugin', 'customField');
  /// // 返回：'plugin.myPlugin.customField'
  /// ```
  static String pluginKey(String pluginName, String key) => '$pluginPrefix$pluginName.$key';

  // ==================== 验证辅助方法 ====================

  /// 检查是否是标准元数据键
  ///
  /// [key] 要检查的键
  ///
  /// 返回 true 如果 [key] 是预定义的标准键
  static bool isStandardKey(String key) => const {
      nodeType,
      isFolder,
      isAI,
      icon,
      color,
      expanded,
      visible,
      locked,
      summary,
      tags,
      priority,
      aiScore,
      aiAnalysis,
      createdAt,
      updatedAt,
      accessedAt,
      version,
      author,
    }.contains(key);

  /// 检查是否是插件元数据键
  ///
  /// [key] 要检查的键
  ///
  /// 返回 true 如果 [key] 以 'plugin.' 开头
  static bool isPluginKey(String key) => key.startsWith(pluginPrefix);
}

/// 优先级标准值
///
/// 定义优先级的常量
class Priorities {
  /// 私有构造函数
  Priorities._();

  /// 最低优先级
  static const int lowest = 0;

  /// 低优先级
  static const int low = 3;

  /// 普通优先级
  static const int normal = 5;

  /// 高优先级
  static const int high = 7;

  /// 最高优先级
  static const int highest = 10;
}
