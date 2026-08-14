/// Concept —— 代码层 schema（00 §2.1）：定义一类 Node 的结构约束与行为。
///
/// **不是 Node，不存储于 Graph**，写死在 Plugin 里。
/// Plugin 是唯一来源。
///
/// 接口必须"薄"（01-E 承诺）：Lua 需能实现它（动态 Concept 引擎）。
/// 任何膨胀的接口都意味着 Lua 插件永远写不出来（02 §1.2）。
library;

import 'drop_semantics.dart';
import 'graph.dart';
import 'hook.dart';
import 'node.dart';

/// Node 的内容要求（02 §1.2）。
enum ContentRequirement {
  /// 必须携带主内容（如笔记正文）。
  required,

  /// 可选。
  optional,

  /// 不允许主内容（纯容器类 Concept）。
  none,
}

/// metadata 字段值类型（02 §1.2 metadataSchema）。
enum MetadataType {
  /// 字符串（含 JSON 标量字符串）。
  string,

  /// 数值（int / double）。
  number,

  /// 布尔。
  boolean,

  /// 数组（List）。
  list,

  /// 对象（Map）。
  map,
}

/// metadataSchema 中的字段定义。
class MetadataField {
  /// 字段声明（名 + 类型）。
  const MetadataField({required this.name, required this.type});

  /// 字段名（metadata 键）。
  final String name;

  /// 字段值类型。
  final MetadataType type;
}

/// Concept 契约（02 §1.2）。
///
/// 修正记录（02 §四）：`FileRef` / `FileRequirement` 已从模型移除——
/// 附件统一为独立节点（asset 类 Concept 实例），因此 createInstance
/// 不含 fileRefs 参数；内容形态由 content + references 表达。
abstract class Concept {
  /// const 子类化支持（Lua 动态 Concept 也可用）。
  const Concept();

  /// 全局唯一，如 'com.example.folder:folder'。
  String get id;

  /// 展示名（插件市场 / 调试）。
  String get name;

  /// 一句话描述。
  String get description;

  /// ---- 结构约束 ----

  /// references key 必须属于此集合。
  Set<String> get slots;

  /// 匹配时必填的 references 键（特异性计分依据之一，02 §1.3）。
  Set<String> get requiredSlots;

  /// metadata 字段声明。
  Map<String, MetadataField> get metadataSchema;

  /// 匹配时必填的 metadata 键（特异性计分依据之一，02 §1.3）。
  Set<String> get requiredMetadataKeys;

  /// 内容要求（required | optional | none）。
  ContentRequirement get contentRequirement;

  /// ---- 行为 ----

  /// 纯结构匹配（00 不变量 4.3-1）：references keys ⊆ slots ∧
  /// required 满足 ∧ metadata required 满足。无 instanceOf。
  bool validate(Node node);

  /// 创建 schema 约束下的新实例（附件 = 独立节点，不含 fileRefs）。
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  });

  /// 呈现面：为 instance 创建 Hook，形态由 context.kind 决定。
  Hook createHook(Node instance, HookContext context);

  /// drop 语义判定（01-C / 03 §三）：容器回答"接收此 Node 意味着什么"。
  ///
  /// 默认拒绝（非容器 Concept 不接收）——容器 Concept 覆写。
  /// 默认实现保证接口"薄"（01-E：Lua 只需在需要时实现）。
  DropSemantics askDropSemantics(Node node) => const RejectDrop('此容器无法容纳这种节点');

  /// 容器语义（00 推论 3）：子级 nodeId 推导——Hook.references 每次
  /// 从"后端图 + schema 匹配 + **容器语义**"重建（M6 回填：
  /// contain 模型下 folder 的 children = 读侧反查，不来自 folder
  /// 自身 references）。
  ///
  /// [graph] 由物化器传入（只读访问，容器语义的推导输入）。
  /// 默认 null = 物化器用 references.values 展开（M3 通用规则）。
  /// 薄接口保证（01-E）：非容器 Concept 无需实现。
  Iterable<String>? childNodeIdsOf(Node node, Graph graph) => null;
}
