/// RecentPanel —— 最近打开面板（C5：Obsidian 最近文件语义，侧边栏 Tab）。
///
/// 面板 = 侧边栏 Tab 的子 Hook（`references.sidebar == 根节点 id`，
/// SidebarTabsView 枚举；'sidebar-panel' 形态 = 最近打开列表）。
/// 数据 = 外观键 `recent.*`（UIStateStore——打开记录由 openNodeDialog
/// 写，判据②；删除节点时键由 DeleteNodeHandler 级联清理——本视图
/// 只读侧直读，零写）。
library;

import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import '../host/host_runtime.dart';
import '../render/flutter_render_context.dart';
import 'node_open_dialog.dart';

/// 最近打开面板 Concept（kind == 'recent-panel'）。
class RecentPanelConcept extends Concept {
  /// 无状态（宿主贡献，可 const 装配）。
  const RecentPanelConcept();

  @override
  String get id => 'com.example.appframe:recent-panel';

  @override
  String get name => '最近打开面板';

  @override
  String get description => '侧边栏最近打开面板（recent.* 键读侧聚合）';

  @override
  Set<String> get slots => const <String>{'sidebar'};

  @override
  Set<String> get requiredSlots => const <String>{'sidebar'};

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
      node.metadata['kind'] == 'recent-panel' &&
      node.references['sidebar'] != null;

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('面板节点由宿主播种（写路径）');
  }

  @override
  Hook createHook(Node instance, HookContext context) => RecentPanelHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// 最近打开面板 Hook（sidebar-panel 形态 = 最近打开列表）。
class RecentPanelHook extends Hook {
  /// 视图面。
  const RecentPanelHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    if (context is! FlutterRenderContext) {
      return;
    }
    final host = context.host;
    final sink = context.sink;
    if (host == null || sink == null) {
      return;
    }
    sink.add(RecentPanelView(host: host));
  }
}

/// 最近打开面板视图（recent.* 键 → 节点列表；点击 → 打开外壳复用）。
class RecentPanelView extends StatefulWidget {
  /// 注入宿主。
  const RecentPanelView({super.key, required this.host});

  /// 宿主组合根。
  final HostRuntime host;

  @override
  State<RecentPanelView> createState() => _RecentPanelViewState();
}

class _RecentPanelViewState extends State<RecentPanelView> {
  /// 最近打开记录（键 → 节点 id；键 = 时间戳，降序 = 最新在前）。
  List<MapEntry<String, String>> _entries() => widget.host.uiStateStore
      .getByPrefix('recent.')
      .entries
      .map((e) => MapEntry<String, String>(e.key, e.value.toString()))
      .toList()
    ..sort((a, b) => b.key.compareTo(a.key));

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    if (entries.isEmpty) {
      return Center(
        child: Text(
          widget.host.i18nService.t('recent.empty'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final node = widget.host.graph.get(entry.value);
        // 防御：节点已删除（键清理级联在 DeleteNodeHandler；极少数
        // 竞态）→ 跳过该行。
        if (node == null) {
          return const SizedBox.shrink();
        }
        return ListTile(
          dense: true,
          leading: const Icon(Icons.history, size: 18),
          title: Text(node.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            widget.host.i18nService.t('recent.openedAt').replaceFirst(
              '%s',
              _formatTs(entry.key),
            ),
          ),
          onTap: () => openNodeDialog(context, widget.host, node.id),
        );
      },
    );
  }

  /// 时间戳（微秒键）→ 可读本地时间。
  String _formatTs(String key) {
    final ts = int.tryParse(key) ?? 0;
    if (ts <= 0) {
      return '';
    }
    final dt = DateTime.fromMicrosecondsSinceEpoch(ts);
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }
}