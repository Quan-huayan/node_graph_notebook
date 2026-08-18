/// FolderConcept —— 文件夹（L0-node，01 拍板 #17）。
///
/// folder 是 **L0-node：references 恒空**——包含关系不持有在自己身上，
/// 由 contain 实例（L1-node）承载（见 contain_concept.dart）。
/// 识别 = 结构匹配：references 为空 ∧ metadata['kind'] == 'folder'
/// （00 不变量 4.3-1：metadata required 满足；显示信息在 metadata）。
///
/// M7 修正（Hook Tree，02 §3.2）：FolderHook.render 挂载 FolderView
/// 容器——子级 = HookView 递归（子 Hook 渲染自己，父不代替子渲染）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';

import 'contain_concept.dart';
import 'folder_card_view.dart';
import 'folder_contents_view.dart';
import 'folder_view.dart';
import 'sidebar_tabs_view.dart';

/// 文件夹 Concept（L0）。
class FolderConcept extends Concept {
  /// 无状态容器（可 const 装配）。
  const FolderConcept();

  @override
  String get id => 'com.example.folder:folder';

  @override
  String get name => '文件夹';

  @override
  String get description => '文件夹（L0-node，包含关系由 contain 实例承载）';

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
      // 结构匹配：L0（references 空）∧ metadata.kind == 'folder'。
      node.references.isEmpty && node.metadata['kind'] == 'folder';

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('folder 实例由导入/命令流程创建');
  }

  @override
  Hook createHook(Node instance, HookContext context) =>
      FolderHook(nodeId: instance.id, hookId: '${instance.id}@${context.kind}');

  @override
  DropSemantics askDropSemantics(Node node) =>
      // 容器判定（01-C / 03 §三）：接收 = 建立 contain 实例
      // （parent=本 folder, child=被拖节点）；由 MoveNodesHandler 落盘。
      const DataMove(<String, String>{});

  @override
  Iterable<String>? childNodeIdsOf(Node node, Graph graph) =>
      // 容器语义（00 推论 3）：children = 读侧反查
      // （references.parent == 本 folder 的 contain 实例的 child）。
      childrenOf(graph, node.id);
}

/// 文件夹 Hook（容器视图面；children 由读侧反查推导）。
class FolderHook extends Hook {
  /// 占位容器视图面。
  const FolderHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    // M7 修正（Hook Tree，02 §3.2）：挂载 FolderView 容器——子级 =
    // HookView 递归（子 Hook 渲染自己）。非 Flutter 渲染目标（测试/
    // 其他后端）→ 静默（Hook 位置无关，02 §3.1）。
    if (context is! FlutterRenderContext) {
      return;
    }
    final flutterContext = context;
    final host = flutterContext.host;
    final sink = flutterContext.sink;
    if (host == null || sink == null) {
      return; // 测试环境：无宿主/收集器 → 不渲染。
    }
    if (flutterContext.kind == 'graph') {
      // M7.1（画布成员 Hook 化）：画布卡片体——位置无关，画布语义
      // （定位/拖拽/菜单）由画布宿主提供。
      sink.add(
        FolderCardView(node: host.graph.get(nodeId)!, i18n: host.i18nService),
      );
      return;
    }
    if (flutterContext.kind == 'open') {
      // M7.2（D1 弹框归属）：打开文件夹 = 子级列表（容器打开呈现的
      // 完整性 = 本 Concept 的责任；外壳由发起方提供）。
      sink.add(FolderContentsView(host: host, node: host.graph.get(nodeId)!));
      return;
    }
    if (flutterContext.kind == 'sidebar-root') {
      // M7.2（Flowing UI 具象化，用户裁决）：侧边栏根 = Tab 容器
      // （文件夹树 + 各插件面板——搜索面板等）。
      sink.add(
        SidebarTabsView(
          host: host,
          node: host.graph.get(nodeId)!,
          // M7.4：面板内拖拽源（搜索行）也上报共享事务起点。
          onDragStart: flutterContext.onDragStart,
        ),
      );
      return;
    }
    sink.add(
      FolderView(
        host: host,
        node: host.graph.get(nodeId)!,
        kind: flutterContext.kind ?? 'sidebar',
      ),
    );
  }
}
