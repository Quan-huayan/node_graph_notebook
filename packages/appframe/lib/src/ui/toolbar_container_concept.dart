/// ToolbarContainerConcept —— 工具栏容器（M7.2，00 删除清单
/// "工具栏 = 容器 Node 的 Hook"落地）。
///
/// 结构匹配 `kind == 'toolbar-root'` 的节点 = 工具栏容器，**子级 =
/// 自动枚举**（childNodeIdsOf = 全部 ToolbarConcept 命中节点，02 §3.2
/// 容器语义推导——AppShell 不再手扫按钮，对齐 FolderView 模式）。
library;

import 'package:core_data/core_data.dart';

import '../render/flutter_render_context.dart';
import 'toolbar_actions_row.dart';
import 'toolbar_concept.dart';

/// 工具栏容器 Concept（appframe 内置——UI 节点机制，非插件私有）。
class ToolbarContainerConcept extends Concept {
  /// 无状态容器（可 const 装配）。
  const ToolbarContainerConcept();

  @override
  String get id => 'com.appframe:toolbar-container';

  @override
  String get name => '工具栏容器';

  @override
  String get description => '工具栏容器节点（子级 = ToolbarConcept 命中节点自动枚举）';

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
  bool validate(Node node) => node.metadata['kind'] == 'toolbar-root';

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('工具栏容器节点由宿主播种（写路径）');
  }

  @override
  Hook createHook(Node instance, HookContext context) => ToolbarContainerHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );

  @override
  Iterable<String>? childNodeIdsOf(Node node, Graph graph) =>
      // 容器语义（00 推论 3）：子级 = 全部工具栏按钮（结构扫描——
      // 与 folder 的 contain 反查同构：枚举归 Concept，宿主零手扫）。
      graph
          .getAll()
          .where((n) => const ToolbarConcept().validate(n))
          .map((n) => n.id)
          .toList();

  @override
  DropSemantics askDropSemantics(Node node) =>
      // M7.4（Flowing UI 落点语义统一）：工具栏是容器——接收任意节点
      // 意味着"建一个打开该节点的按钮"（判据① 数据命令）。具体命令
      // 由 ToolbarDropSemantics 服务在 DragController 命令工厂中路由
      // （插件 last-wins 覆盖）。
      const DataMove(<String, String>{});
}

/// 工具栏容器 Hook（渲染按钮行——子级 = HookView 递归，02 §3.2
/// 父 Hook 驱动子 Hook，不代替子渲染）。
class ToolbarContainerHook extends Hook {
  /// 容器视图面。
  const ToolbarContainerHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    final flutterContext = context as FlutterRenderContext;
    final host = flutterContext.host;
    final sink = flutterContext.sink;
    if (host == null || sink == null) {
      return; // 测试环境：无宿主/收集器 → 不渲染。
    }
    sink.add(ToolbarActionsRow(host: host, node: host.graph.get(nodeId)!));
  }
}
