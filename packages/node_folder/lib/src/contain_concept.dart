/// ContainConcept —— folder ↔ note 的包含关系（00 §2.2 / 01 拍板 #17-19）。
///
/// folder 与 note 都是 **L0-node（references 恒空）**；包含关系由
/// **contain 实例（L1-node）引用两端**承载：
/// `contain.references = {parent: <folder>, child: <note>}`。
/// 多子级 = 多个 contain 实例；folder 的 children = 读侧反查。
library;

import 'package:core_data/core_data.dart';

/// 包含关系 Concept（L1：引用 parent 与 child 两个 L0-node）。
class ContainConcept extends Concept {
  /// 无状态关系 schema（可 const 装配）。
  const ContainConcept();

  @override
  String get id => 'com.example.folder:contain';

  @override
  String get name => '包含关系';

  @override
  String get description => 'folder ↔ note 的包含关系（L1-node，引用两端）';

  @override
  Set<String> get slots => const <String>{'parent', 'child'};

  @override
  Set<String> get requiredSlots => const <String>{'parent', 'child'};

  @override
  Map<String, MetadataField> get metadataSchema =>
      const <String, MetadataField>{};

  @override
  Set<String> get requiredMetadataKeys => const <String>{};

  @override
  ContentRequirement get contentRequirement => ContentRequirement.none;

  @override
  bool validate(Node node) {
    // 结构匹配：references keys ⊆ slots ∧ required 满足（00 不变量 4.3-1）。
    if (!node.references.keys.every(slots.contains)) {
      return false;
    }
    for (final required in requiredSlots) {
      if (node.references[required] == null) {
        return false;
      }
    }
    return true;
  }

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('contain 实例由移动命令创建');
  }

  @override
  Hook createHook(Node instance, HookContext context) => ContainHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// 关系 Hook（L1 关系呈现——M6 占位；真正渲染归 M7+ UI）。
class ContainHook extends Hook {
  /// 占位关系 Hook。
  const ContainHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    // M6 占位：关系行呈现由宿主接入。
  }
}

/// 读侧反查：folder 的 children（references.parent == folderId 的
/// contain 实例的 child 集合）。
///
/// 10⁶ 优化项：references 反查索引（M6 用全量扫描，数据量小可接受）。
Iterable<String> childrenOf(Graph graph, String folderId) => graph
    .getAll()
    .where((n) => n.references['parent'] == folderId)
    .map((n) => n.references['child']!);

/// 语义后代检查：拖 folder 进自己后代 = 逻辑环（00 §2.3 预判）。
///
/// [ancestorId] 是否在 [nodeId] 的后代里（沿 contain.child 传播）。
/// Ln 模型下 references 天然无环，但"folderA 包含 folderB 且 folderB
/// 包含 folderA"是语义矛盾——由本检查拒绝（M6 用 childrenOf 扫描，
/// 10⁶ 优化项：反查索引传播）。
///
/// M7.2 修复（运行时暴露的卡死）：① **拖进自己 = 逻辑环**（画布卡片
/// 拖到侧边栏同名文件夹 tile——isDescendant 只查后代不查自身，漏放
/// 行产生自引用 contain → 树递归渲染自己 + 本检查无限递归）；②
/// **visited 剪枝**：contain 图异常成环时递归无限（每层全图扫描，
/// UI 线程卡死）——visited 集合保证终止。
bool isDescendant(Graph graph, String nodeId, String ancestorId) =>
    _isDescendant(graph, nodeId, ancestorId, <String>{});

bool _isDescendant(
  Graph graph,
  String nodeId,
  String ancestorId,
  Set<String> visited,
) {
  if (nodeId == ancestorId) {
    return true; // 拖进自己 = 逻辑环（自引用）。
  }
  if (!visited.add(nodeId)) {
    return false; // 已访问（图异常有环）→ 剪枝终止。
  }
  for (final child in childrenOf(graph, nodeId)) {
    if (_isDescendant(graph, child, ancestorId, visited)) {
      return true;
    }
  }
  return false;
}
