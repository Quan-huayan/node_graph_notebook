/// LuaConcept —— 脚本化 Concept 桥（M7，01-E 承诺落地）。
///
/// Lua 脚本定义的 Concept（`Concept` 全局表）经本桥实现 Dart 的
/// `Concept` 接口——**接口薄度验证**：validate / createHook 委托 Lua
/// 函数，结构约束（slots/requiredSlots/metadataSchema/...）来自 Lua 表。
///
/// 脚本约定（data/lua_scripts/*.lua）：
/// ```lua
/// Concept = {
///   id = "com.example.mine:special",
///   name = "特殊节点",
///   description = "Lua 动态 Concept",
///   slots = {},
///   requiredSlots = {},
///   requiredMetadataKeys = {"kind"},
///   contentRequirement = "none",   -- "required" | "optional" | "none"
///   validate = function(node)
///     return node.metadata.kind == "special"
///   end,
///   createHook = function(node, kind)
///     return { nodeId = node.id, hookId = node.id .. "@" .. kind }
///   end,
/// }
/// ```
///
/// node 参数 = 引擎拼的 Lua 表字面量（id/title/content/references/metadata）。
library;

import 'package:core_data/core_data.dart';

import 'lua_engine.dart';

/// Lua 脚本定义的动态 Concept。
class LuaConcept extends Concept {
  /// 由脚本表与引擎装配。
  LuaConcept({
    required this.id,
    required this.name,
    required this.description,
    required this.slots,
    required this.requiredSlots,
    required this.requiredMetadataKeys,
    required this.contentRequirement,
    required this.hasValidate,
    required this.hasCreateHook,
    required this.engine,
  });

  /// 全局唯一 id（脚本表提供）。
  @override
  final String id;

  /// 展示名（脚本表提供）。
  @override
  final String name;

  /// 描述（脚本表提供）。
  @override
  final String description;

  /// references key 白名单。
  @override
  final Set<String> slots;

  /// 匹配必填 references 键。
  @override
  final Set<String> requiredSlots;

  /// 匹配必填 metadata 键。
  @override
  final Set<String> requiredMetadataKeys;

  /// 内容要求。
  @override
  final ContentRequirement contentRequirement;

  /// 脚本是否定义 validate（未定义 → Dart 侧结构匹配）。
  final bool hasValidate;

  /// 脚本是否定义 createHook（未定义 → 默认 LuaHook）。
  final bool hasCreateHook;

  /// 引擎（执行 validate/createHook）。
  final LuaEngine engine;

  /// metadata schema：脚本未声明 → 空（结构匹配靠 requiredMetadataKeys）。
  @override
  Map<String, MetadataField> get metadataSchema =>
      const <String, MetadataField>{};

  /// 归属判定 = Lua validate（纯结构匹配，00 不变量 4.3-1）。
  ///
  /// 脚本未定义 validate → 用 required 约束的 Dart 侧结构匹配
  /// （slots ⊆ references ∧ required 满足——兜底不空洞）。
  @override
  bool validate(Node node) {
    if (!hasValidate) {
      if (!node.references.keys.every(slots.contains)) {
        return false;
      }
      for (final required in requiredSlots) {
        if (node.references[required] == null) {
          return false;
        }
      }
      for (final required in requiredMetadataKeys) {
        if (node.metadata[required] == null) {
          return false;
        }
      }
      return true;
    }
    final result = engine.evalBound(
      'return Concept.validate(${_nodeLiteral(node)})',
    );
    return result == true;
  }

  /// 呈现面：委托 Lua createHook（返回 {nodeId, hookId}）；未定义 →
  /// 默认 LuaHook（nodeId@kind）。
  @override
  Hook createHook(Node instance, HookContext context) {
    if (!hasCreateHook) {
      return LuaHook(
        nodeId: instance.id,
        hookId: '${instance.id}@${context.kind}',
      );
    }
    final result = engine.evalBound(
      'return Concept.createHook(${_nodeLiteral(instance)}, '
      "'${context.kind}')",
    );
    if (result is Map<String, dynamic> &&
        result['nodeId'] is String &&
        result['hookId'] is String) {
      return LuaHook(
        nodeId: result['nodeId'] as String,
        hookId: result['hookId'] as String,
      );
    }
    // 脚本返回值异常 → 兜底（永不空洞，00 不变量 4.3-3）。
    return LuaHook(
      nodeId: instance.id,
      hookId: '${instance.id}@${context.kind}',
    );
  }

  /// 创建实例（Dart 侧默认——createInstance 的调用方是命令流程，
  /// 数据形态由 Dart 构造；脚本无需实现）。
  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('Lua Concept 实例由宿主命令流程创建');
  }

  /// 节点 → Lua 表字面量。
  ///
  /// 修正记录（M7）：
  /// 1. 字符串键必须方括号形式——Lua 表构造器里裸字符串键
  ///    是语法错误（字段名须为标识符或方括号表达式）。
  /// 2. null 字段省略键——nil 值字段也是语法错误
  ///    （缺失键 = nil，语义等价）。
  String _nodeLiteral(Node node) {
    final parts = <String>[
      "['id'] = '${node.id}'",
      "['title'] = ${LuaEngine.toLuaLiteral(node.title)}",
    ];
    final content = node.content;
    if (content != null) {
      parts.add("['content'] = ${LuaEngine.toLuaLiteral(content)}");
    }
    parts
      ..add("['references'] = ${LuaEngine.toLuaLiteral(node.references)}")
      ..add("['metadata'] = ${LuaEngine.toLuaLiteral(node.metadata)}");
    return '{${parts.join(', ')}}';
  }
}

/// Lua 脚本 Hook（脚本化呈现占位——M7 验证接口薄度；
/// 脚本 Hook 的 UI 能力留 M7+）。
class LuaHook extends Hook {
  /// 占位 Hook。
  const LuaHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    // M7 占位：脚本 Hook 无 UI；动态 Concept 的归属/校验是本期验证点。
  }
}
