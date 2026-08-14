/// AIConcept —— AI 节点（L0-node，00 杀手演示"拖进 AI 节点 → 变对话"）。
///
/// AI 节点 = **L0-node：references 恒空**（同 folder 模式，01 拍板 #30）——
/// 对话关系不持有在自己身上，由 chat 实例（L1-node）承载（chat_concept.dart）。
/// 识别 = 结构匹配：`metadata['kind'] == 'ai'`（00 不变量 4.3-1）。
///
/// 容器语义（00 推论 3）：会话 = 读侧反查（references.ai == 本节点的
/// chat 实例的 source 集合）。
///
/// M7 修正（Hook 承载 UI）：AIHook.render 挂载 AIChatView（kind =
/// 'open'——点击 AI 节点 = 渲染其 Hook = 对话视图，"变对话"的呈现）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

import 'ai_card_view.dart';
import 'ai_chat_view.dart';
import 'ai_provider_config.dart';
import 'chat_concept.dart';

/// AI 节点 Concept（L0 容器）。
class AIConcept extends Concept {
  /// 无状态容器（可 const 装配）。
  const AIConcept();

  @override
  String get id => 'com.example.ai:ai';

  @override
  String get name => 'AI 节点';

  @override
  String get description => 'AI 节点（L0-node，对话关系由 chat 实例承载）';

  /// L0：不引用任何 Node。
  @override
  Set<String> get slots => const <String>{};

  @override
  Set<String> get requiredSlots => const <String>{};

  @override
  Map<String, MetadataField> get metadataSchema =>
      const <String, MetadataField>{
        'kind': MetadataField(name: 'kind', type: MetadataType.string),
      };

  @override
  Set<String> get requiredMetadataKeys => const <String>{'kind'};

  @override
  ContentRequirement get contentRequirement => ContentRequirement.none;

  @override
  bool validate(Node node) =>
      // 结构匹配：L0（references 空）∧ metadata.kind == 'ai'。
      node.references.isEmpty && node.metadata['kind'] == 'ai';

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('AI 节点由创建命令/种子流程创建');
  }

  @override
  Hook createHook(Node instance, HookContext context) =>
      AIHook(nodeId: instance.id, hookId: '${instance.id}@${context.kind}');

  @override
  DropSemantics askDropSemantics(Node node) =>
      // 容器判定（01-C / 03 §三）：接收 = 建立/更新 chat 实例
      // （{ai: 本节点, source: 被拖节点}）；由 DropIntoAIHandler 落盘。
      // 引用内容由 app 组合根的 moveCommandFactory 分发
      // （01 拍板 #32：插件互相不依赖，语义分发归宿主）。
      const DataMove(<String, String>{});

  @override
  Iterable<String>? childNodeIdsOf(Node node, Graph graph) =>
      // 容器语义（00 推论 3）：会话 = 读侧反查
      // （references.ai == 本节点的 chat 实例的 source 集合）。
      chatsOf(graph, node.id);
}

/// AI 节点 Hook（渲染对话视图——kind = 'open' 时挂载 AIChatView）。
class AIHook extends Hook {
  /// 容器视图面。
  const AIHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    // M7 修正（Hook 承载 UI）：挂载对话视图（AIChatView）——服务注入
    // （graph/commandBus 经宿主服务解析），不依赖组合根 host。
    // 非 Flutter 渲染目标（测试/其他后端）→ 静默（Hook 位置无关）。
    if (context is! FlutterRenderContext) {
      return;
    }
    final host = context.host;
    final sink = context.sink;
    if (host == null || sink == null) {
      return;
    }
    if (context.kind == 'graph') {
      // M7.1（画布成员 Hook 化）：画布卡片体 = 会话入口（点击 =
      // 渲染 'open' Hook = 对话视图）；不能挂完整对话视图进卡片。
      sink.add(
        AICardView(node: host.graph.get(nodeId)!, i18n: host.i18nService),
      );
      return;
    }
    sink.add(
      AIChatView(
        graph: host.serviceProvider.get<Graph>(),
        commandBus: host.serviceProvider.get<CommandBus>(),
        aiNodeId: nodeId,
        config: host.serviceProvider.get<AIProviderConfig>(),
        i18n: host.i18nService,
      ),
    );
  }
}
