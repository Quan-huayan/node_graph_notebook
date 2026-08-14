/// ChatConcept —— AI ↔ 笔记的对话会话（00 §2.2 / 01 拍板 #30）。
///
/// AI 节点与笔记都是 **L0-node（references 恒空）**；对话关系由
/// **chat 实例（L1-node）引用两端**承载：
/// `chat.references = {ai: <AI节点>, source: <笔记>}`。
/// 一个 source 一个 chat 实例（拖到另一个 AI 节点 = 更新 ai，同
/// contain 模式）；消息历史 = chat 实例 content（markdown 序列化，
/// chat_messages.dart）。
library;

import 'package:core_data/core_data.dart';

/// 对话会话 Concept（L1：引用 ai 与 source 两个 L0-node）。
class ChatConcept extends Concept {
  /// 无状态关系 schema（可 const 装配）。
  const ChatConcept();

  @override
  String get id => 'com.example.ai:chat';

  @override
  String get name => '对话会话';

  @override
  String get description => 'AI ↔ 笔记的对话会话（L1-node，消息 = content）';

  @override
  Set<String> get slots => const <String>{'ai', 'source'};

  @override
  Set<String> get requiredSlots => const <String>{'ai', 'source'};

  @override
  Map<String, MetadataField> get metadataSchema =>
      const <String, MetadataField>{};

  @override
  Set<String> get requiredMetadataKeys => const <String>{};

  @override
  ContentRequirement get contentRequirement => ContentRequirement.optional;

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
    throw UnimplementedError('chat 实例由拖入/发送命令创建');
  }

  @override
  Hook createHook(Node instance, HookContext context) =>
      ChatHook(nodeId: instance.id, hookId: '${instance.id}@${context.kind}');
}

/// 会话 Hook（L1 关系呈现——占位；对话 UI = AIChatDialog）。
class ChatHook extends Hook {
  /// 占位关系 Hook。
  const ChatHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    // M7 呈现：会话行由 AIChatDialog 承载。
  }
}

/// 读侧反查：AI 节点的会话 source 集合（references.ai == aiNodeId 的
/// chat 实例的 source）。容器语义（00 推论 3），同 folder 的 childrenOf。
///
/// 10⁶ 优化项：references 反查索引（M7 用全量扫描，数据量小可接受）。
///
/// 修正记录（M7.3 实测）：**必须按 ChatConcept 过滤**——AI 面板节点
/// （references {sidebar, ai}，ai_panel_concept.dart）也持有
/// references.ai 但无 source 键；不过滤会把面板当会话，
/// `references['source']!` 空值崩溃（"Null check operator used on a null
/// value"——拖 AI 节点入侧边栏钉面板后，打开 tab / 任何结构变更重渲染
/// 即崩，连接节点同样触发）。
Iterable<String> chatsOf(Graph graph, String aiNodeId) {
  const chatConcept = ChatConcept();
  return graph
      .getAll()
      .where((n) => n.references['ai'] == aiNodeId && chatConcept.validate(n))
      .map((n) => n.references['source']!);
}

/// 查某笔记的 chat 实例（references.source == sourceId）。
///
/// 一个 source 一个会话（同 contain 模式）；拖到另一 AI 节点 = 更新 ai。
Node? chatOfSource(Graph graph, String sourceId) =>
    graph.getAll().where((n) => n.references['source'] == sourceId).firstOrNull;
