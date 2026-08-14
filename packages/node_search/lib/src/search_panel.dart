/// SearchPanel —— 搜索面板（M7.2，用户裁决：搜索在侧边栏）。
///
/// 面板 = 侧边栏 Tab 的子 Hook（`references.sidebar == 根节点 id`，
/// SidebarTabsView 枚举；'sidebar-panel' 形态 = 输入 + 结果列表 +
/// 点击打开节点）。纯读侧服务（01 拍板 #36）。
library;

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
      ),
    );
  }
}

/// 搜索面板视图（输入 + 结果 + 点击打开节点）。
class SearchPanelView extends StatefulWidget {
  /// 注入宿主与搜索服务。
  const SearchPanelView({super.key, required this.host, required this.search});

  /// 宿主组合根。
  final HostRuntime host;

  /// 搜索服务（读侧）。
  final SearchService search;

  @override
  State<SearchPanelView> createState() => _SearchPanelViewState();
}

class _SearchPanelViewState extends State<SearchPanelView> {
  final TextEditingController _input = TextEditingController();
  List<Node> _results = const <Node>[];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {
      _results = widget.search.search(SearchQuery(text: text));
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: _input,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: widget.host.i18nService.t('search.hint'),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: _onChanged,
        ),
      ),
      Expanded(
        child: _results.isEmpty
            ? Center(
                child: Text(
                  widget.host.i18nService.t('search.hint'),
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
                  return Draggable<String>(
                    data: node.id,
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
                      leading: const Icon(Icons.description, size: 18),
                      title: Text(
                        node.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _openNode(context, node.id),
                    ),
                  );
                },
              ),
      ),
    ],
  );

  /// 打开节点 = 渲染其 Hook（D1 打开契约：发起方负责外壳）。
  void _openNode(BuildContext context, String nodeId) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 640,
          height: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: widget.host.i18nService.t('dialog.close'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: HookView(
                  host: widget.host,
                  nodeId: nodeId,
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
