
import '../../utils/logger.dart';

/// Logger for HookPointDefinition
const _log = AppLogger('HookPointDefinition');

/// Hook 点定义
///
/// 描述一个 Hook 点的完整信息，包括 ID、名称、描述、上下文类型等
///
/// 架构说明：
/// - 替代原有的 HookPointId 枚举，支持动态注册 Hook 点
/// - 提供丰富的元数据和类型信息
/// - 支持上下文数据验证（通过 contextSchema）
/// - 允许第三方插件注册自定义 Hook 点
class HookPointDefinition {
  /// 创建一个新的 Hook 点定义实例。
  ///
  /// [id] Hook 点 ID（建议使用点分隔的格式，如 'main.toolbar'）
  /// [name] Hook 点显示名称
  /// [description] Hook 点描述
  /// [category] Hook 点分类（如 'toolbar', 'sidebar', 'context_menu'）
  /// [contextType] Hook 点的上下文类型（用于类型安全）
  /// [contextSchema] 上下文数据模式（可选，用于验证上下文数据）
  const HookPointDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.contextType,
    this.contextSchema,
  });

  /// Hook 点 ID
  ///
  /// 建议格式：使用点分隔的层级结构
  /// 示例：
  /// - 'main.toolbar' - 主工具栏
  /// - 'sidebar.top' - 侧边栏顶部
  /// - 'context_menu.node' - 节点上下文菜单
  final String id;

  /// Hook 点显示名称
  ///
  /// 示例：'Main Toolbar', 'Sidebar Top', 'Node Context Menu'
  final String name;

  /// Hook 点描述
  ///
  /// 详细描述此 Hook 点的用途和适用场景
  final String description;

  /// Hook 点分类
  ///
  /// 用于对 Hook 点进行分组管理
  /// 常见分类：
  /// - 'toolbar' - 工具栏
  /// - 'sidebar' - 侧边栏
  /// - 'context_menu' - 上下文菜单
  /// - 'dialog' - 对话框
  /// - 'panel' - 面板
  final String category;

  /// Hook 点的上下文类型
  ///
  /// 用于类型安全，确保 Hook 使用正确的上下文类型
  ///
  /// 示例：
  /// - MainToolbarHookContext
  /// - SidebarHookContext
  /// - NodeContextMenuHookContext
  final Type? contextType;

  /// 上下文数据模式
  ///
  /// 可选，用于验证上下文数据是否包含必需的字段
  /// Map 的 key 是字段名，value 是字段类型
  ///
  /// 示例：
  /// ```dart
  /// contextSchema: {
  ///   'buildContext': BuildContext,
  ///   'node': Node,
  ///   'isSelected': bool,
  /// }
  /// ```
  final Map<String, Type>? contextSchema;

  /// 验证上下文数据是否符合模式
  ///
  /// [contextData] 要验证的上下文数据
  /// 返回 true 如果数据符合模式，否则返回 false
  bool validateContext(Map<String, dynamic> contextData) {
    if (contextSchema == null) return true;

    for (final entry in contextSchema!.entries) {
      final key = entry.key;
      final expectedType = entry.value;

      if (!contextData.containsKey(key)) {
        _log.info('Missing required context key: $key');
        return false;
      }

      final value = contextData[key];
      if (value != null && value.runtimeType != expectedType) {
        _log.warning('[HookPointDefinition] Context key $key has wrong type: '
            'expected $expectedType, got ${value.runtimeType}');
        return false;
      }
    }

    return true;
  }

  @override
  String toString() =>
      'HookPointDefinition($id, $name, category: $category)';
}

/// Hook 点注册表
///
/// 管理所有 Hook 点的注册和查询
///
/// 架构说明：
/// - 替代原有的 HookPointId 枚举，支持动态注册
/// - 全局单例，由系统初始化时注册标准 Hook 点
/// - 允许插件注册自定义 Hook 点
/// - 提供 Hook 点查询和验证功能
class HookPointRegistry {
  /// 创建一个新的 Hook 点注册表实例
  HookPointRegistry();

  /// 已注册的 Hook 点
  ///
  /// Key: Hook 点 ID
  /// Value: Hook 点定义
  final Map<String, HookPointDefinition> _points = {};

  /// 注册 Hook 点
  ///
  /// [point] 要注册的 Hook 点定义
  ///
  /// 抛出 ArgumentError 如果 Hook 点 ID 已存在
  void registerPoint(HookPointDefinition point) {
    if (_points.containsKey(point.id)) {
      throw ArgumentError('Hook point already registered: ${point.id}');
    }

    _points[point.id] = point;
    _log.info('Registered hook point: ${point.id}');
  }

  /// 获取 Hook 点定义
  ///
  /// [id] Hook 点 ID
  /// 返回 Hook 点定义，如果不存在则返回 null
  HookPointDefinition? getPoint(String id) => _points[id];

  /// 检查 Hook 点是否存在
  ///
  /// [id] Hook 点 ID
  /// 返回 true 如果 Hook 点已注册
  bool hasPoint(String id) => _points.containsKey(id);

  /// 获取所有 Hook 点
  ///
  /// 返回所有已注册的 Hook 点定义列表
  List<HookPointDefinition> getAllPoints() => _points.values.toList();

  /// 按分类获取 Hook 点
  ///
  /// [category] Hook 点分类
  /// 返回指定分类的所有 Hook 点
  List<HookPointDefinition> getPointsByCategory(String category) =>
      _points.values.where((point) => point.category == category).toList();

  /// 注销 Hook 点
  ///
  /// [id] Hook 点 ID
  ///
  /// 注意：不建议注销标准 Hook 点
  void unregisterPoint(String id) {
    final removed = _points.remove(id);
    if (removed != null) {
      _log.info('Unregistered hook point: $id');
    }
  }

  /// 清空所有 Hook 点
  ///
  /// 主要用于测试
  void clear() {
    _points.clear();
  }

  /// 获取已注册的 Hook 点数量
  int get count => _points.length;

  @override
  String toString() =>
      'HookPointRegistry(count: $count, points: ${_points.keys.join(", ")})';
}
