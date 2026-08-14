/// SettingsContainerConcept —— 设置容器（M7.2 阶段 C，用户裁决：
/// settings 聚合 = Hook Tree 既有表达，无新扩展点）。
///
/// 结构匹配 `kind == 'settings-root'` 的节点 = 设置容器；**子级 = 各
/// 插件自己的设置节点**（AI key = node_ai、语言 = node_i18n、主题 =
/// 本插件），聚合 = **references 反查**（`references.settings == 容器
/// id`——contain/chatsOf 既有模式，插件不互依靠数据引用满足，04 §三
/// 约束 3）。打开设置容器 = 渲染其 Hook（D1 打开契约：发起方弹框）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';

import 'settings_entries_view.dart';

/// 设置容器 Concept（node_settings 内置）。
class SettingsContainerConcept extends Concept {
  /// 无状态容器（可 const 装配）。
  const SettingsContainerConcept();

  @override
  String get id => 'com.example.settings:container';

  @override
  String get name => '设置';

  @override
  String get description => '设置容器节点（子级 = references.settings 反查）';

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
  bool validate(Node node) => node.metadata['kind'] == 'settings-root';

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('设置容器节点由宿主播种（写路径）');
  }

  @override
  Hook createHook(Node instance, HookContext context) => SettingsContainerHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );

  @override
  Iterable<String>? childNodeIdsOf(Node node, Graph graph) =>
      // 容器语义（00 推论 3）：子级 = references.settings == 本容器的
      // 设置条目（L1 反查——contain/chatsOf 模式，零跨插件依赖）。
      graph
          .getAll()
          .where((n) => n.references['settings'] == node.id)
          .map((n) => n.id)
          .toList();
}

/// 设置容器 Hook（打开 = 渲染条目列表）。
class SettingsContainerHook extends Hook {
  /// 容器视图面。
  const SettingsContainerHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    // 打开设置容器 = 渲染其 Hook = 条目列表（外壳由发起方提供，
    // D1 打开契约：画布/工具栏弹框者负责 close 与回收）。
    if (context is! FlutterRenderContext) {
      return;
    }
    final host = context.host;
    final sink = context.sink;
    if (host == null || sink == null) {
      return; // 测试环境：无宿主/收集器 → 不渲染。
    }
    sink.add(SettingsEntriesView(host: host, node: host.graph.get(nodeId)!));
  }
}
