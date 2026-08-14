/// 画布成员卡片物化渲染测试（M7.1：UIManager 物化 Hook 渲染 + 定向重建）。
///
/// 成员卡片 = 成员节点自己的物化 Hook 渲染（kind='graph'）→ data 失效
/// 只重建命中成员（画布不整树重建）→ 兜底回退通用卡片体（永不空洞）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

/// 画布卡片测试插件：匹配节点的 'graph' Hook 渲染计数 marker。
class _GraphCardPlugin extends Plugin {
  _GraphCardPlugin({required this.concept});

  final _GraphCardConcept concept;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'test.graphcard',
    name: '画布卡片测试',
    version: '1.0.0',
  );

  @override
  void registerExtensions(ExtensionRegistry registry) {
    registry.addContribution(conceptPoint, concept, ownerPluginId: metadata.id);
  }
}

/// 计数 Concept：命中节点的 'graph' 形态 = 计数 marker（重建判据）。
class _GraphCardConcept extends Concept {
  _GraphCardConcept({required this.matchNodeIds});

  final Set<String> matchNodeIds;

  @override
  String get id => 'test.graphcard:card';

  @override
  String get name => '画布卡片';

  @override
  String get description => '测试画布成员经物化 Hook 渲染';

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
  bool validate(Node node) => matchNodeIds.contains(node.id);

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('测试不创建实例');
  }

  @override
  Hook createHook(Node instance, HookContext context) => _GraphCardHook(
    nodeId: instance.id,
    kind: context.kind,
    counter: counterOf(instance.id),
  );
}

/// 只挂 'graph' 形态的测试 Hook（其他形态空——模拟 Lua 动态 Concept）。
class _GraphCardHook extends Hook {
  _GraphCardHook({
    required this.nodeId,
    required this.kind,
    required this.counter,
  });

  @override
  final String nodeId;

  final String kind;
  final _Counter counter;

  @override
  String get hookId => '$nodeId@$kind';

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    final flutterContext = context as FlutterRenderContext;
    if (flutterContext.kind != 'graph') {
      return; // 物化时的占位 render（sink 丢弃）不挂载。
    }
    flutterContext.mount(_CountingCard(label: nodeId, counter: counter));
  }
}

/// 计数 marker（build 次数 = 卡片重建次数）。
class _CountingCard extends StatelessWidget {
  const _CountingCard({required this.label, required this.counter});

  final String label;
  final _Counter counter;

  @override
  Widget build(BuildContext context) {
    counter.builds++;
    return Text('hook-card-$label');
  }
}

class _Counter {
  int builds = 0;
}

final Map<String, _Counter> _counters = <String, _Counter>{};

_Counter counterOf(String nodeId) =>
    _counters.putIfAbsent(nodeId, _Counter.new);

/// 种子 + 启动：canvas + root + noteA/noteB（noteA 有位置键）。
Future<HostRuntime> seed(
  Directory root,
  _GraphCardConcept concept, {
  Map<String, Offset> positions = const <String, Offset>{
    'noteA': Offset(100, 100),
    'noteB': Offset(420, 200),
  },
}) async {
  final host = HostRuntime(dataRoot: root);
  final now = DateTime.now();
  <StoredNode>[
    StoredNode(
      id: 'root',
      title: '根目录',
      metadata: const <String, dynamic>{'kind': 'folder'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'canvas',
      title: '画布',
      metadata: const <String, dynamic>{'kind': 'canvas'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'noteA',
      title: '笔记A',
      content: 'A 的内容',
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'noteB',
      title: '笔记B',
      content: 'B 的内容',
      createdAt: now,
      updatedAt: now,
    ),
  ].forEach(host.graph.save);
  for (final entry in positions.entries) {
    host.uiStateStore.set(canvasPositionKey(entry.key), <String, dynamic>{
      'x': entry.value.dx,
      'y': entry.value.dy,
    });
  }
  // servicesProvider：宿主最新 provider 入口（M7 修正——多插件场景
  // onLoad 快照被 dispose，命令延迟解析必须经此入口）。
  ServiceProvider resolveServices() => host.serviceProvider;
  await host.start(
    plugins: <Plugin>[
      GraphPlugin(servicesProvider: resolveServices),
      _GraphCardPlugin(concept: concept),
    ],
    rootNodeId: 'root',
    rootKind: 'sidebar',
  );
  return host;
}

/// 测试壳：全屏画布。
class _Harness extends StatelessWidget {
  const _Harness({required this.host});

  final HostRuntime host;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: GraphCanvas(host: host)),
  );
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_graphcard');
    _counters.clear();
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('画布成员卡片 = 成员节点自己的物化 Hook 渲染（kind=graph）', (tester) async {
    final concept = _GraphCardConcept(matchNodeIds: const <String>{'noteA'});
    final host = await seed(root, concept);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // noteA：物化 Hook 渲染（marker 卡片体）；noteB：兜底 → 通用卡片体。
    expect(find.text('hook-card-noteA'), findsOneWidget);
    expect(find.text('笔记B'), findsOneWidget);
    expect(find.text('笔记A'), findsNothing); // noteA 不走通用体。
  });

  testWidgets('data 失效 → 只重建命中成员卡片（画布不整树重建）', (tester) async {
    final concept = _GraphCardConcept(
      matchNodeIds: const <String>{'noteA', 'noteB'},
    );
    final host = await seed(root, concept);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();
    final aBuilds = counterOf('noteA').builds;
    final bBuilds = counterOf('noteB').builds;

    // 改 noteA 标题（data 写）→ 只重建 noteA 卡片。
    await host.commandBus.dispatch<UpdateNodeCommand, UpdateNodeResult>(
      const UpdateNodeCommand(nodeId: 'noteA', title: '改名A', content: '新内容'),
    );
    await tester.pump();

    expect(counterOf('noteA').builds, aBuilds + 1); // 命中 → 卡片重建。
    expect(counterOf('noteB').builds, bBuilds); // 未命中 → 画布不整树重建。
    expect(find.text('hook-card-noteA'), findsOneWidget);
  });
}
