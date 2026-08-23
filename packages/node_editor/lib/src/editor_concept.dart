/// NoteConcept —— 普通笔记（M7 修正，Hook 承载 UI 的归属侧落地）。
///
/// 普通笔记（references 空 ∧ 无 kind）的归属 = 本 Concept（原兜底
/// Concept 无 UI）——**点击笔记 = 渲染其 Hook = 编辑器视图**。
/// 特异性：required 0——folder（required kind）等有 kind 的 Concept
/// 特异性更高，优先匹配（02 §1.3 匹配优先序）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

import 'markdown_editor_view.dart';
import 'note_card_view.dart';
import 'note_row_view.dart';

/// 普通笔记 Concept。
class NoteConcept extends Concept {
  /// 无状态（可 const 装配）。
  const NoteConcept();

  @override
  String get id => 'com.example.editor:note';

  @override
  String get name => '笔记';

  @override
  String get description => '普通笔记（L0，编辑器渲染）';

  @override
  Set<String> get slots => const <String>{};

  @override
  Set<String> get requiredSlots => const <String>{};

  @override
  Map<String, MetadataField> get metadataSchema =>
      const <String, MetadataField>{};

  @override
  Set<String> get requiredMetadataKeys => const <String>{};

  @override
  ContentRequirement get contentRequirement => ContentRequirement.optional;

  @override
  bool validate(Node node) =>
      // 普通笔记：references 空 ∧ 无 kind（folder/ai/canvas 有 kind，
      // 特异性更高优先——本 Concept 只命中真正的普通笔记）。
      node.references.isEmpty && node.metadata['kind'] == null;

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('笔记实例由创建命令流程创建');
  }

  @override
  Hook createHook(Node instance, HookContext context) => EditorHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
    instance: instance,
  );
}

/// 笔记 Hook（kind = 'open' 时挂载编辑器视图）。
class EditorHook extends Hook {
  /// 构造（携带节点数据）。
  EditorHook({
    required this.nodeId,
    required this.hookId,
    required this.instance,
  });

  @override
  final String nodeId;

  @override
  final String hookId;

  /// 笔记节点。
  final Node instance;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    // M7 修正（Hook Tree，02 §1.2）：**形态由 kind 决定**——
    // 'sidebar' → 笔记行（侧边栏子 Hook 渲染）；'open' → 编辑器视图。
    // 服务注入（commandBus 经宿主服务解析），不依赖组合根 host。
    // 非 Flutter 渲染目标（测试/其他后端）→ 静默（Hook 位置无关）。
    if (context is! FlutterRenderContext) {
      return;
    }
    final host = context.host;
    final sink = context.sink;
    if (host == null || sink == null) {
      return;
    }
    // M7.1（物化实例复用）：render 时重读自己 Node（02 §3.4 主动读）——
    // 失效后定向重建渲染的是新数据，不持有陈旧快照。
    final node = host.graph.get(nodeId) ?? instance;
    if (context.kind == 'sidebar') {
      sink.add(
        NoteRowView(host: host, node: node, onDragStart: context.onDragStart),
      );
      return;
    }
    if (context.kind == 'graph') {
      // M7.1（画布成员 Hook 化）：画布卡片体——位置无关，画布语义
      // （定位/拖拽/菜单）由画布宿主提供。
      sink.add(NoteCardView(node: node, i18n: host.i18nService));
      return;
    }
    sink.add(
      MarkdownEditorView(
        commandBus: host.serviceProvider.get<CommandBus>(),
        node: node,
        i18n: host.i18nService,
        // A2/A3/A4：知识语义扩展——host + 壳层服务（A2 标签 chips /
        // A3 反链区 / A4 单节点导出，null = 区块隐藏）。
        host: host,
        tagService: host.serviceProvider.get<TagService>(),
        backlinkService: host.serviceProvider.get<BacklinkService>(),
        shellSignals: host.shellSignals,
        // A4：converter 插件注册的 targeted 动作（未注册 → null 隐藏）。
        onExportNote: host.toolbarActions
            .lookupTargeted('converter.exportNote'),
      ),
    );
  }
}
