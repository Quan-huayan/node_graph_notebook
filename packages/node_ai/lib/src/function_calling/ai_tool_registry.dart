/// AI 工具注册表（M7.3，archive/ai 资产带走）——plugon 服务，
/// 插件 onLoad 注册工具；owner 保护防止插件互相覆盖。
library;

import 'ai_tool.dart';

/// AI 工具注册表。
class AIToolRegistry {
  /// 已注册工具（id → 实例）。
  final Map<String, AITool> _tools = <String, AITool>{};

  /// 工具拥有者（id → 插件 id；防覆盖）。
  final Map<String, String> _toolOwners = <String, String>{};

  /// 注册工具（同 id 已被其他插件注册 → 抛异常）。
  void registerTool(AITool tool, {String? pluginId}) {
    final existingOwner = _toolOwners[tool.id];
    if (existingOwner != null &&
        pluginId != null &&
        existingOwner != pluginId) {
      throw AIToolRegistrationException(
        'Tool "${tool.id}" is already registered by plugin "$existingOwner". '
        'Cannot override with plugin "$pluginId".',
      );
    }
    _tools[tool.id] = tool;
    if (pluginId != null) {
      _toolOwners[tool.id] = pluginId;
    }
  }

  /// 批量注册。
  void registerTools(List<AITool> tools, {String? pluginId}) {
    for (final tool in tools) {
      registerTool(tool, pluginId: pluginId);
    }
  }

  /// 注销（owner 不匹配 → 静默忽略）。
  void unregisterTool(String toolId, {String? pluginId}) {
    final owner = _toolOwners[toolId];
    if (owner != null && pluginId != null && owner != pluginId) {
      return;
    }
    _tools.remove(toolId);
    _toolOwners.remove(toolId);
  }

  /// 查工具（不存在 → null）。
  AITool? getTool(String toolId) => _tools[toolId];

  /// 是否存在。
  bool hasTool(String toolId) => _tools.containsKey(toolId);

  /// 全部工具。
  List<AITool> getAllTools() => _tools.values.toList();

  /// 按分类。
  List<AITool> getToolsByCategory(String category) =>
      _tools.values.where((tool) => tool.category == category).toList();

  /// 工具 id 列表。
  List<String> getToolIds() => _tools.keys.toList();

  /// 清空（测试用）。
  void clear() {
    _tools.clear();
    _toolOwners.clear();
  }

  /// 工具数量。
  int get toolCount => _tools.length;

  /// OpenAI function calling 格式。
  List<Map<String, dynamic>> toOpenAIFormat() => _tools.values
      .map(
        (tool) => <String, dynamic>{
          'type': 'function',
          'function': <String, dynamic>{
            'name': tool.id,
            'description': tool.description,
            'parameters': tool.parametersSchema,
          },
        },
      )
      .toList();
}

/// 工具注册异常（同 id 已被其他插件注册）。
class AIToolRegistrationException implements Exception {
  /// 构造异常。
  const AIToolRegistrationException(this.message);

  /// 错误消息。
  final String message;

  @override
  String toString() => 'AIToolRegistrationException: $message';
}
