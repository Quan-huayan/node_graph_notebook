/// ConnectionConcept —— 节点间连接关系（00 §2.2：边 = L1-node 实例）。
///
/// 连接 = **连接实例（L1-node）引用两端**：`connect.references = {from, to}`
/// ——不是 Edge 类（00 删除清单），是恰好引用两个 Node 的 Node，由本
/// Concept 解释为"连接"。无向边（M6 简化）：from/to 双向等价。
///
/// 识别 = 结构匹配：references keys ⊆ {from, to} ∧ 两端必填
/// （与 contain 的 {parent, child} slots 不冲突——00 不变量 4.3-1）。
/// 连接实例本身不在画布显示（画布成员 = 位置键，L1 无位置键，天然隐藏）。
library;

import 'package:core_data/core_data.dart';

/// 连接关系 Concept（L1）。
class ConnectionConcept extends Concept {
  /// 无状态关系 schema（可 const 装配）。
  const ConnectionConcept();

  @override
  String get id => 'com.example.graph:connection';

  @override
  String get name => '连接关系';

  @override
  String get description => '节点间连接（L1-node，references {from, to}，无向）';

  @override
  Set<String> get slots => const <String>{'from', 'to'};

  @override
  Set<String> get requiredSlots => const <String>{'from', 'to'};

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
    return node.references['from'] != null && node.references['to'] != null;
  }

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('连接实例由 ConnectNodesHandler 创建');
  }

  @override
  Hook createHook(Node instance, HookContext context) => ConnectionHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// 连接关系 Hook（画布上连接实例不显示为卡片——仅连接线渲染读取）。
class ConnectionHook extends Hook {
  /// 占位关系 Hook。
  const ConnectionHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    // 连接线渲染由 GraphCanvas 直读连接实例（画布不物化连接 Hook）。
  }
}
