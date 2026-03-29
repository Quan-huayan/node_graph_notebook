/// Hook 优先级枚举
///
/// 定义语义化的优先级级别，替代原有的魔法数字
///
/// 架构说明：
/// - 使用语义化名称（如 critical、high、medium）替代数字
/// - 每个优先级对应一个数值，数值越小优先级越高
/// - 保持向后兼容：默认值 (100) 与旧系统默认 priority 相同
/// - 解决手动优先级数字导致的冲突问题
///
/// 优先级建议值（工具栏按钮）：
/// - 0-99: 系统关键级别
/// - 100-199: 核心功能（创建节点、图管理）
/// - 200-299: 布局和视图控制
/// - 300-399: 数据操作（导入导出）
/// - 400-499: 配置和设置
/// - 500-599: 扩展功能（AI助手）
/// - 600-699: 插件和市场
/// - 700+: 装饰性元素
enum HookPriority {
  /// 关键级别（优先级最高）
  ///
  /// 用于系统关键功能，如保存按钮、撤销/重做等
  /// 数值：0
  critical(0),

  /// 自定义级别 50（设置）
  ///
  /// 用于设置功能，应该在主工具栏最右边
  /// 数值：50
  custom50(50),

  /// 自定义级别 60（插件市场）
  ///
  /// 用于插件市场功能，应该在主工具栏右二位置
  /// 数值：60
  custom60(60),

  /// 自定义级别 70（AI助手）
  ///
  /// 用于AI助手功能
  /// 数值：70
  custom70(70),

  /// 自定义级别 80（导入导出）
  ///
  /// 用于导入导出功能
  /// 数值：80
  custom80(80),

  /// 自定义级别 90（语言切换）
  ///
  /// 用于语言切换功能
  /// 数值：90
  custom90(90),

  /// 高级别
  ///
  /// 用于重要功能，如搜索、创建节点等
  /// 数值：100
  high(100),

  /// 自定义级别 100（创建节点）
  ///
  /// 用于创建节点功能
  /// 数值：100
  custom100(100),

  /// 自定义级别 150（图节点管理）
  ///
  /// 用于核心图管理功能
  /// 数值：150
  custom150(150),

  /// 自定义级别 200（切换连接线）
  ///
  /// 用于切换连接线显示功能
  /// 数值：200
  custom200(200),

  /// 自定义级别 250（刷新图）
  ///
  /// 用于刷新图功能
  /// 数值：250
  custom250(250),

  /// 自定义级别 300（布局控制）
  ///
  /// 用于布局和视图控制
  /// 数值：300
  custom300(300),

  /// 中级别（默认级别）
  ///
  /// 用于标准功能，如布局、导入导出等
  /// 数值：800
  medium(800),

  /// 低级别
  ///
  /// 用于可选功能，如插件扩展等
  /// 数值：900
  low(900),

  /// 装饰级别（优先级最低）
  ///
  /// 用于纯装饰性元素，如分隔符、图标等
  /// 数值：1000
  decorative(1000);

  /// 创建优先级枚举实例
  ///
  /// [value] 优先级数值
  const HookPriority(this.value);

  /// 优先级数值
  ///
  /// 数值越小，优先级越高
  final int value;

  /// 从数值解析优先级
  ///
  /// 兼容旧系统的整数优先级
  /// 如果数值不在预定义范围内，返回 medium
  ///
  /// [value] 优先级数值
  /// 返回对应的 HookPriority 枚举值
  static HookPriority fromValue(int value) {
    if (value <= 0) return HookPriority.critical;
    if (value <= 300) return HookPriority.high;
    if (value <= 700) return HookPriority.medium;
    if (value <= 900) return HookPriority.low;
    return HookPriority.decorative;
  }

  @override
  String toString() => '$name (value: $value)';
}

/// Hook 优先级扩展
///
/// 提供 HookPriority 的实用工具方法
extension HookPriorityExtension on HookPriority {
  /// 是否高于指定优先级
  ///
  /// [other] 要比较的优先级
  /// 返回 true 如果当前优先级高于 other
  bool isHigherThan(HookPriority other) => value < other.value;

  /// 是否低于指定优先级
  ///
  /// [other] 要比较的优先级
  /// 返回 true 如果当前优先级低于 other
  bool isLowerThan(HookPriority other) => value > other.value;

  /// 是否等于指定优先级
  ///
  /// [other] 要比较的优先级
  /// 返回 true 如果当前优先级等于 other
  bool isEqualTo(HookPriority other) => value == other.value;
}
