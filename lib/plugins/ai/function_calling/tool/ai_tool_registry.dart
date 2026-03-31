import '../../../../core/utils/logger.dart';
import '../tools/connect_nodes_tool.dart';
import '../tools/create_node_tool.dart';
import '../tools/delete_node_tool.dart';
import '../tools/list_nodes_tool.dart';
import '../tools/search_nodes_tool.dart';
import '../tools/update_node_tool.dart';
import 'ai_tool.dart';

/// AI 工具注册表
///
/// 单例模式，管理所有可用的 AI 工具
///
/// 架构说明：
/// - 插件可以在 onLoad() 时注册自定义工具
/// - 工具按 ID 去重，重复注册会覆盖
/// - 支持按分类、优先级查询工具
/// - 提供 AI 提供商特定的工具格式转换
class AIToolRegistry {
  /// 私有构造函数（单例模式）
  AIToolRegistry._();

  /// 单例实例
  static final AIToolRegistry _instance = AIToolRegistry._();

  /// 获取单例实例
  static AIToolRegistry get instance => _instance;

  /// 已注册的工具映射
  /// key: tool ID, value: tool instance
  final Map<String, AITool> _tools = {};

  /// 工具拥有者映射
  ///
  /// key: tool ID, value: plugin ID
  /// 防止插件覆盖其他插件的工具
  final Map<String, String> _toolOwners = {};

  /// 是否已初始化（内置工具是否已注册）
  bool _initialized = false;

  /// 注册工具
  ///
  /// [tool] - 工具实例
  /// [pluginId] - 插件 ID（用于权限控制）
  ///
  /// 如果工具 ID 已存在且属于其他插件，抛出异常
  void registerTool(AITool tool, {String? pluginId}) {
    // 检查工具是否已被其他插件注册
    final existingOwner = _toolOwners[tool.id];
    if (existingOwner != null && pluginId != null && existingOwner != pluginId) {
      throw AIToolRegistrationException(
        'Tool "${tool.id}" is already registered by plugin "$existingOwner". '
        'Cannot override with plugin "$pluginId".',
      );
    }

    _tools[tool.id] = tool;
    if (pluginId != null) {
      _toolOwners[tool.id] = pluginId;
    }
    const AppLogger('AIToolRegistry').info(
      'Registered tool: ${tool.id} (${tool.name})${pluginId != null ? ' by $pluginId' : ''}',
    );
  }

  /// 批量注册工具
  ///
  /// [tools] - 工具列表
  void registerTools(List<AITool> tools) {
    tools.forEach(registerTool);
  }

  /// 注销工具
  ///
  /// [toolId] - 工具 ID
  /// [pluginId] - 插件 ID（必须匹配工具拥有者）
  ///
  /// 如果工具不存在或插件不拥有该工具，静默忽略
  void unregisterTool(String toolId, {String? pluginId}) {
    // 检查插件是否拥有该工具
    final owner = _toolOwners[toolId];
    if (owner != null && pluginId != null && owner != pluginId) {
      const AppLogger('AIToolRegistry').warning(
        'Plugin "$pluginId" attempted to unregister tool "$toolId" owned by "$owner"',
      );
      return;
    }

    _tools.remove(toolId);
    _toolOwners.remove(toolId);
    const AppLogger('AIToolRegistry').info(
      'Unregistered tool: $toolId${pluginId != null ? ' by $pluginId' : ''}',
    );
  }

  /// 获取工具
  ///
  /// [toolId] - 工具 ID
  ///
  /// 返回工具实例，如果不存在则返回 null
  AITool? getTool(String toolId) => _tools[toolId];

  /// 检查工具是否存在
  ///
  /// [toolId] - 工具 ID
  bool hasTool(String toolId) => _tools.containsKey(toolId);

  /// 获取所有工具
  ///
  /// 返回所有已注册的工具列表
  List<AITool> getAllTools() => _tools.values.toList();

  /// 按分类获取工具
  ///
  /// [category] - 工具分类
  ///
  /// 返回指定分类的工具列表
  List<AITool> getToolsByCategory(String category) => _tools.values.where((tool) => tool.category == category).toList();

  /// 获取工具 ID 列表
  ///
  /// 返回所有工具的 ID 列表
  List<String> getToolIds() => _tools.keys.toList();

  /// 清空所有工具
  ///
  /// 主要用于测试
  void clear() {
    _tools.clear();
    _toolOwners.clear();
    _initialized = false;
  }

  /// 转换为 OpenAI 格式
  ///
  /// 返回符合 OpenAI function calling 格式的工具列表
  ///
  /// 格式示例：
  /// ```json
  /// [{
  ///   "type": "function",
  ///   "function": {
  ///     "name": "create_node",
  ///     "description": "Create a new node...",
  ///     "parameters": {
  ///       "type": "object",
  ///       "properties": {...},
  ///       "required": ["title"]
  ///     }
  ///   }
  /// }]
  /// ```
  List<Map<String, dynamic>> toOpenAIFormat() => _tools.values.map((tool) => {
        'type': 'function',
        'function': {
          'name': tool.id,
          'description': tool.description,
          'parameters': tool.parametersSchema,
        },
      }).toList();

  /// 转换为 Anthropic 格式
  ///
  /// 返回符合 Anthropic tool use 格式的工具列表
  ///
  /// 格式示例：
  /// ```json
  /// [{
  ///   "name": "create_node",
  ///   "description": "Create a new node...",
  ///   "input_schema": {
  ///     "type": "object",
  ///     "properties": {...},
  ///     "required": ["title"]
  ///   }
  /// }]
  /// ```
  List<Map<String, dynamic>> toAnthropicFormat() => _tools.values.map((tool) => {
        'name': tool.id,
        'description': tool.description,
        'input_schema': tool.parametersSchema,
      }).toList();

  /// 转换为智谱 AI 格式
  ///
  /// 智谱 AI 使用与 OpenAI 兼容的格式
  List<Map<String, dynamic>> toZhipuAIFormat() => toOpenAIFormat();

  /// 获取适用于特定提供商的工具
  ///
  /// [provider] - AI 提供商类型
  ///
  /// 返回该提供商支持的工具列表
  List<AITool> getToolsFor(String provider) =>
    // 默认返回所有工具
    // 子类可以覆盖此方法以实现提供商特定的工具过滤
    getAllTools();

  /// 初始化内置工具
  ///
  /// 注册所有内置工具（节点操作、搜索等）
  /// 应该在应用启动时调用一次
  void initializeBuiltinTools() {
    if (_initialized) return;

    final builtinTools = [
      // 节点操作工具
      CreateNodeTool(),
      UpdateNodeTool(),
      DeleteNodeTool(),

      // 搜索工具
      SearchNodesTool(),
      ListNodesTool(),

      // 连接工具
      ConnectNodesTool(),
    ];

    registerTools(builtinTools);
    _initialized = true;

    const AppLogger('AIToolRegistry').info(
      'Initialized ${builtinTools.length} builtin tools',
    );
  }

  /// 获取已注册的工具数量
  int get toolCount => _tools.length;

  /// 获取初始化状态
  bool get isInitialized => _initialized;
}

/// AI 工具注册异常
///
/// 工具注册失败时抛出此异常（例如：工具已被其他插件注册）
class AIToolRegistrationException implements Exception {
  /// 创建工具注册异常
  ///
  /// [message] 错误消息
  const AIToolRegistrationException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'AIToolRegistrationException: $message';
}
