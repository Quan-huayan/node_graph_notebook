/// AIPanelConcept —— AI 侧边栏面板（M7.3 Flowing UI）。
///
/// 面板 = **L1 实例节点**（references {sidebar, ai}）——拖 AI 节点入
/// 侧边栏时由 CreateAIPanelCommand 创建；SidebarTabsView 枚举
/// （references.sidebar == root）自动成为侧边栏 tab「AI 对话」，
/// tab 内容 = 本 Hook（kind='sidebar-panel'）→ 会话列表视图。
///
/// AI 节点自身零变更（AIConcept L0 匹配 references.isEmpty 不被破坏）；
/// 多 AI 节点 = 多面板实例（每节点独立面板/会话，零硬编码）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import 'chat_concept.dart';

/// AI 面板 Concept（结构匹配 references {ai, sidebar}）。
class AIPanelConcept extends Concept {
  /// 无状态（可 const 装配）。
  const AIPanelConcept();

  @override
  String get id => 'com.example.ai:ai-panel';

  @override
  String get name => 'AI 侧边栏面板';

  @override
  String get description => 'AI 会话面板（references {sidebar, ai}）';

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
  ContentRequirement get contentRequirement => ContentRequirement.none;

  @override
  bool validate(Node node) =>
      node.references['ai'] != null && node.references['sidebar'] != null;

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('AI 面板由 CreateAIPanelCommand 创建（写路径）');
  }

  @override
  Hook createHook(Node instance, HookContext context) => AIPanelHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// AI 面板 Hook（kind='sidebar-panel' → 会话列表；其他形态不渲染）。
class AIPanelHook extends Hook {
  /// 构造（节点 id 定位）。
  const AIPanelHook({required this.nodeId, required this.hookId});

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
    if (host == null ||
        sink == null ||
        flutterContext.kind != 'sidebar-panel') {
      return; // 测试环境 / 非面板形态。
    }
    final node = host.graph.get(nodeId);
    if (node == null) {
      return;
    }
    final aiNodeId = node.references['ai'];
    if (aiNodeId == null || host.graph.get(aiNodeId) == null) {
      return; // AI 节点已删 → 面板悬空，不渲染。
    }
    sink.add(AIPanelView(host: host, aiNodeId: aiNodeId));
  }
}

/// AI 面板视图（侧边栏紧凑会话列表；点击会话 → 打开对话对话框）。
class AIPanelView extends StatelessWidget {
  /// 注入宿主与 AI 节点。
  const AIPanelView({super.key, required this.host, required this.aiNodeId});

  /// 宿主组合根。
  final HostRuntime host;

  /// AI 节点 id。
  final String aiNodeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = chatsOf(host.graph, aiNodeId).toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 面板头：AI 节点标题 + 会话数。
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  host.graph.get(aiNodeId)?.title ?? 'AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text('${sources.length}', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: sources.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      host.i18nService.t('ai.panelHint'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                )
              : ListView(
                  children: [
                    for (final sourceId in sources)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.forum_outlined, size: 18),
                        title: Text(
                          host.graph.get(sourceId)?.title ?? sourceId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openChat(context),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// 打开对话（全视图对话框——AIChatView 内含会话选择；M7.2 D1
  /// 弹框归属：发起方提供外壳，内容 = Hook 渲染）。
  void _openChat(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 760,
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: host.i18nService.t('dialog.close'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: HookView(
                  host: host,
                  nodeId: aiNodeId,
                  kind: 'open',
                  recycleOnDispose: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
