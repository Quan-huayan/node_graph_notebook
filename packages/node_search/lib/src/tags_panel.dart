/// TagsPanel —— 标签面板（A2：Obsidian 标签面板语义，侧边栏 Tab）。
///
/// 面板 = 侧边栏 Tab 的子 Hook（`references.sidebar == 根节点 id`，
/// SidebarTabsView 枚举；'sidebar-panel' 形态 = 标签云 + 点击列笔记）。
/// 纯读侧：数据 = TagService（appframe 壳层服务，DI 解析——插件互不依赖，
/// 04 §三 约束 3）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// 标签面板 Concept（kind == 'tags-panel'）。
class TagsPanelConcept extends Concept {
  /// 无状态（可 const 装配）。
  const TagsPanelConcept();

  @override
  String get id => 'com.example.search:tags-panel';

  @override
  String get name => '标签面板';

  @override
  String get description => '侧边栏标签面板（#tag 聚合）';

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
      node.metadata['kind'] == 'tags-panel' &&
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
  Hook createHook(Node instance, HookContext context) => TagsPanelHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// 标签面板 Hook（sidebar-panel 形态 = 标签视图）。
class TagsPanelHook extends Hook {
  /// 视图面。
  const TagsPanelHook({required this.nodeId, required this.hookId});

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
    sink.add(
      TagsPanelView(
        host: host,
        tags: host.serviceProvider.get<TagService>(),
        onDragStart: context.onDragStart,
      ),
    );
  }
}

/// 标签面板视图（标签计数列表 → 点击展开该标签的笔记列表）。
class TagsPanelView extends StatefulWidget {
  /// 注入宿主与标签服务。
  const TagsPanelView({
    super.key,
    required this.host,
    required this.tags,
    this.onDragStart,
  });

  /// 宿主组合根。
  final HostRuntime host;

  /// 标签服务（壳层读侧）。
  final TagService tags;

  /// 结果行拖拽起点上报（共享 DragController，M7.4）。
  final DragStartHandler? onDragStart;

  @override
  State<TagsPanelView> createState() => _TagsPanelViewState();
}

class _TagsPanelViewState extends State<TagsPanelView> {
  /// 展开查看的标签（null = 显示标签列表）。
  String? _expandedTag;

  @override
  Widget build(BuildContext context) {
    final expanded = _expandedTag;
    if (expanded == null) {
      return _buildTagList(context);
    }
    return _buildTagNotes(context, expanded);
  }

  /// 标签列表（计数降序——TagService 已排序）。
  Widget _buildTagList(BuildContext context) {
    final entries = widget.tags.tagsWithCount().entries.toList();
    if (entries.isEmpty) {
      return Center(
        child: Text(
          widget.host.i18nService.t('tags.empty'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.tag, size: 18),
          title: Text('${entry.key}（${entry.value}）'),
          onTap: () => setState(() => _expandedTag = entry.key),
        );
      },
    );
  }

  /// 标签笔记列表（点击打开 / 拖拽源）。
  Widget _buildTagNotes(BuildContext context, String tag) {
    final nodes = widget.tags.nodesForTag(tag);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          dense: true,
          title: Text('#$tag'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: widget.host.i18nService.t('tags.back'),
            onPressed: () => setState(() => _expandedTag = null),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: nodes.isEmpty
              ? Center(
                  child: Text(
                    widget.host.i18nService.t('search.noResults'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  itemCount: nodes.length,
                  itemBuilder: (context, index) {
                    final node = nodes[index];
                    return Builder(
                      builder: (rowContext) => Draggable<String>(
                        data: node.id,
                        onDragStarted: () {
                          final box =
                              rowContext.findRenderObject() as RenderBox?;
                          widget.onDragStart?.call(
                            node.id,
                            box == null
                                ? Offset.zero
                                : box.localToGlobal(Offset.zero),
                          );
                        },
                        feedback: Material(
                          color: Colors.transparent,
                          child: Card(
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(node.title, maxLines: 1),
                            ),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.description_outlined,
                              size: 18),
                          title: Text(
                            node.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => openNodeDialog(context, widget.host, node.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}