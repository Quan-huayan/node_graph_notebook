/// SearchPanel —— 搜索面板（M7.2，用户裁决：搜索在侧边栏）。
///
/// 面板 = 侧边栏 Tab 的子 Hook（`references.sidebar == 根节点 id`，
/// SidebarTabsView 枚举；'sidebar-panel' 形态 = 输入 + 结果列表 +
/// 点击打开节点）。纯读侧服务（01 拍板 #36）。
library;

import 'dart:async';

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import 'search_service.dart';

/// 搜索面板 Concept（kind == 'search-panel'）。
class SearchPanelConcept extends Concept {
  /// 无状态（可 const 装配）。
  const SearchPanelConcept();

  @override
  String get id => 'com.example.search:panel';

  @override
  String get name => '搜索面板';

  @override
  String get description => '侧边栏搜索面板';

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
      node.metadata['kind'] == 'search-panel' &&
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
  Hook createHook(Node instance, HookContext context) => SearchPanelHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// 搜索面板 Hook（sidebar-panel 形态 = 搜索视图）。
class SearchPanelHook extends Hook {
  /// 视图面。
  const SearchPanelHook({required this.nodeId, required this.hookId});

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
      SearchPanelView(
        host: host,
        search: host.serviceProvider.get<SearchService>(),
        onDragStart: context.onDragStart,
      ),
    );
  }
}

/// 搜索面板视图（输入 + 结果 + 点击打开节点）。
class SearchPanelView extends StatefulWidget {
  /// 注入宿主与搜索服务。
  const SearchPanelView({
    super.key,
    required this.host,
    required this.search,
    this.onDragStart,
  });

  /// 宿主组合根。
  final HostRuntime host;

  /// 搜索服务（读侧）。
  final SearchService search;

  /// 结果行拖拽起点上报（共享 DragController，M7.4）。
  final DragStartHandler? onDragStart;

  @override
  State<SearchPanelView> createState() => _SearchPanelViewState();
}

class _SearchPanelViewState extends State<SearchPanelView> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Node> _results = const <Node>[];
  // C3：最近查询（会话态，判据③——不落盘；容量 10，去重置顶）。
  final List<String> _recentQueries = <String>[];
  Timer? _debounce;
  late final void Function() _onSearchSignal;

  /// 防抖窗口（输入停顿后触发搜索——大仓库下避免每键全量扫描抖动）。
  static const Duration _debounceDuration = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    // Ctrl+F（壳层信号，P1-4）→ 聚焦输入框并全选——键盘直达搜索，
    // 无需再点一次输入框（判据③ 会话态：信号只通知不落盘）。
    // A2：`requestTagSearch(tag)`（编辑器标签 chip 点击）→ 输入框置
    // `tag:<tag>` 过滤并聚焦（消费后 pendingTagFilter 置回 null）。
    _onSearchSignal = () {
      if (!mounted) {
        return;
      }
      final pendingTag = widget.host.shellSignals.pendingTagFilter;
      if (pendingTag != null) {
        widget.host.shellSignals.pendingTagFilter = null;
        _input.text = 'tag:$pendingTag';
        _onChanged(_input.text);
      }
      _focusNode.requestFocus();
      _input.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _input.text.length,
      );
    };
    widget.host.shellSignals.addListener(_onSearchSignal);
  }

  @override
  void dispose() {
    widget.host.shellSignals.removeListener(_onSearchSignal);
    _debounce?.cancel();
    _input.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    // 防抖：停止输入 _debounceDuration 后才搜索（大仓库性能 UX）。
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (mounted) {
        setState(() {
          _results = widget.search.search(_queryOf(text));
          // C3：最近查询记录（去重置顶、容量 10——会话态）。
          final norm = text.trim();
          if (norm.isNotEmpty) {
            _recentQueries.remove(norm);
            _recentQueries.insert(0, norm);
            if (_recentQueries.length > 10) {
              _recentQueries.removeLast();
            }
          }
        });
      }
    });
  }

  /// 输入 → 查询（`tag:`/`folder:` 前缀解析——A2 标签 / C3 文件夹过滤；
  /// 余词为文本）。
  static SearchQuery _queryOf(String text) {
    final trimmed = text.trim();
    final tagMatch =
        RegExp(r'^tag:([\p{L}\p{N}_-]+)\s*(.*)$', unicode: true)
            .firstMatch(trimmed);
    if (tagMatch != null) {
      return SearchQuery(
        text: tagMatch.group(2)!.trim(),
        tag: tagMatch.group(1),
      );
    }
    final folderMatch =
        RegExp(r'^folder:([\p{L}\p{N}_-]+)\s*(.*)$', unicode: true)
            .firstMatch(trimmed);
    if (folderMatch != null) {
      return SearchQuery(
        text: folderMatch.group(2)!.trim(),
        folderId: folderMatch.group(1),
      );
    }
    return SearchQuery(text: trimmed);
  }

  /// 内容摘要（空白折叠 + 截断——结果行可读性，用户无需打开即可判断）。
  static String _snippet(String content) {
    final collapsed = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.length <= 48
        ? collapsed
        : '${collapsed.substring(0, 48)}…';
  }

  @override
  Widget build(BuildContext context) {
    final query = _input.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _input,
            focusNode: _focusNode,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.host.i18nService.t('search.hint'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: _onChanged,
          ),
        ),
        // 结果计数（有查询词时显示——搜索反馈明确化）。
        if (query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
            child: Text(
              widget.host.i18nService
                  .t('search.resultsCount')
                  .replaceFirst('%s', '${_results.length}'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        Expanded(
          child: query.isEmpty
              ? _recentQueries.isEmpty
                  ? Center(
                      child: Text(
                        widget.host.i18nService.t('search.hint'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            widget.host.i18nService.t('search.recent'),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              for (final q in _recentQueries)
                                ActionChip(
                                  label: Text(
                                    q,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onPressed: () {
                                    _input.text = q;
                                    _onChanged(q);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    )
              : _results.isEmpty
              ? Center(
                  child: Text(
                    widget.host.i18nService.t('search.noResults'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final node = _results[index];
                    // M7.3（Flowing UI 三向拖拽）：结果行 = 拖拽源——
                    // 拖到侧边栏 folder = 列表项（MoveNodes）、拖到画布 =
                    // 卡片（位置直写）、拖到工具栏 = 按钮（CreateToolbar-
                    // ButtonCommand）。落点语义全在既有 DragTarget，本行
                    // 只提供 Draggable（data = nodeId，对齐 NoteRowView）。
                    // Builder：itemBuilder 的 context.renderObject 是
                    // RenderSliverList，不能直接 localToGlobal；拿行级
                    // BuildContext 才能量到结果行 RenderBox（M7.4）。
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
                          leading: Icon(_kindIcon(node), size: 18),
                          title: Text(
                            node.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // 内容摘要（命中内容可预览，无需打开节点）。
                          subtitle:
                              node.content == null ||
                                  node.content!.trim().isEmpty
                              ? null
                              : Text(
                                  _snippet(node.content!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                          onTap: () => _openNode(rowContext, node.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 结果行图标（kind 感知——同 GenericNodeCardBody 的映射约定）。
  static IconData _kindIcon(Node node) => switch (node.metadata['kind']) {
    'folder' => Icons.folder_outlined,
    'ai' => Icons.smart_toy_outlined,
    _ => Icons.description_outlined,
  };

  /// 打开节点 = 渲染其 Hook（D1 打开契约：外壳收敛 = openNodeDialog 共用
  /// 助手）。
  void _openNode(BuildContext context, String nodeId) {
    openNodeDialog(context, widget.host, nodeId);
  }
}
