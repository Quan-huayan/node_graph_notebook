/// HookView 物化宿主测试（M7.1：UIManager 管线接入 widget 树）。
///
/// 物化路径：渲染 UIManager 物化实例（重建不重派生）→ data 失效定向
/// 重建（只命中节点）→ structure 树重挂重新物化 → recycleOnDispose
/// 关闭即回收 → 未 started 回退重派生路径。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon.dart';

/// 计数测试插件：贡献计数 Concept + data/structure 两种失效写命令。
class _TestPlugin extends Plugin {
  _TestPlugin({required this.concept});

  final _CountConcept concept;

  @override
  PluginMetadata get metadata =>
      const PluginMetadata(id: 'test.hookview', name: '测试', version: '1.0.0');

  @override
  void registerExtensions(ExtensionRegistry registry) {
    registry.addContribution(conceptPoint, concept, ownerPluginId: metadata.id);
    registry.addContribution(
      commandHandlerPoint,
      _DataTouchHandler(),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      _StructureTouchHandler(),
      ownerPluginId: metadata.id,
    );
  }
}

/// 计数 Concept：记录 createHook 次数（物化 ≠ 重派生的判据）。
class _CountConcept extends Concept {
  _CountConcept({required this.matchNodeIds});

  final Set<String> matchNodeIds;

  /// createHook 调用计数（物化每次 +1）。
  int createCount = 0;

  @override
  String get id => 'test.hookview:count';

  @override
  String get name => '计数';

  @override
  String get description => '测试 HookView 物化宿主';

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
  Hook createHook(Node instance, HookContext context) {
    createCount++;
    return _MarkerHook(
      nodeId: instance.id,
      kind: context.kind,
      counter: counterOf(instance.id),
    );
  }
}

/// 测试内共享的构建计数器（key = nodeId）。
final Map<String, _Counter> _counters = <String, _Counter>{};

_Counter counterOf(String nodeId) =>
    _counters.putIfAbsent(nodeId, _Counter.new);

/// 构建计数（marker widget 每次 build +1——重建判据）。
class _Counter {
  int builds = 0;
}

/// 挂载 marker 文本的测试 Hook（物化渲染 = 位置无关）。
class _MarkerHook extends Hook {
  _MarkerHook({
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
    (context as FlutterRenderContext).mount(
      _Marker(label: nodeId, counter: counter),
    );
  }
}

/// 计数 marker（build 次数 = 呈现层重建次数）。
class _Marker extends StatelessWidget {
  const _Marker({required this.label, required this.counter});

  final String label;
  final _Counter counter;

  @override
  Widget build(BuildContext context) {
    counter.builds++;
    return Text('marker-$label');
  }
}

/// data 失效写命令（changeKind = data）。
class _DataTouchCommand extends Command<_DataTouchCommand> {
  const _DataTouchCommand({required this.nodeId});

  final String nodeId;

  @override
  String get name => 'data.touch';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{'nodeId': nodeId};
}

/// structure 失效写命令（changeKind = structure）。
class _StructureTouchCommand extends Command<_StructureTouchCommand> {
  const _StructureTouchCommand({required this.nodeId});

  final String nodeId;

  @override
  String get name => 'structure.touch';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{'nodeId': nodeId};
}

class _DataTouchHandler
    extends CommandHandler<_DataTouchCommand, _TouchResult> {
  @override
  Type get commandType => _DataTouchCommand;

  @override
  Future<_TouchResult> handle(_DataTouchCommand command) async =>
      _TouchResult(affected: <String>{command.nodeId}, kind: ChangeKind.data);
}

class _StructureTouchHandler
    extends CommandHandler<_StructureTouchCommand, _TouchResult> {
  @override
  Type get commandType => _StructureTouchCommand;

  @override
  Future<_TouchResult> handle(_StructureTouchCommand command) async =>
      _TouchResult(
        affected: <String>{command.nodeId},
        kind: ChangeKind.structure,
      );
}

class _TouchResult implements WriteResult {
  const _TouchResult({required this.affected, required this.kind});

  final Set<String> affected;
  final ChangeKind kind;

  @override
  Set<String> get affectedNodeIds => affected;

  @override
  ChangeKind get changeKind => kind;

  @override
  Command? get inverse => null;
}

/// 测试壳：两个 HookView（a / b）+ 强制重建按钮。
class _Harness extends StatefulWidget {
  const _Harness({required this.host});

  final HostRuntime host;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _extra = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HookView(host: widget.host, nodeId: 'a', kind: 'sidebar'),
          HookView(host: widget.host, nodeId: 'b', kind: 'sidebar'),
          // 无数据变化的强制重建（验证重建不重派生）。
          TextButton(
            onPressed: () => setState(() => _extra = !_extra),
            child: const Text('rebuild'),
          ),
        ],
      ),
    ),
  );
}

/// 种子：root + a + b（HookView 直接渲染 a/b；root = 物化根）。
HostRuntime _seed(Directory root, {required _CountConcept concept}) {
  final host = HostRuntime(dataRoot: root);
  final now = DateTime.now();
  <StoredNode>[
    StoredNode(id: 'root', title: '根', createdAt: now, updatedAt: now),
    StoredNode(id: 'a', title: 'A', createdAt: now, updatedAt: now),
    StoredNode(id: 'b', title: 'B', createdAt: now, updatedAt: now),
  ].forEach(host.graph.save);
  return host;
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_hookview');
    _counters.clear();
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('物化路径：渲染 UIManager 物化实例（重建不重派生）', (tester) async {
    final concept = _CountConcept(
      matchNodeIds: const <String>{'root', 'a', 'b'},
    );
    final host = _seed(root, concept: concept);
    await host.start(
      plugins: <Plugin>[_TestPlugin(concept: concept)],
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );

    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    expect(find.text('marker-a'), findsOneWidget);
    expect(find.text('marker-b'), findsOneWidget);
    // 物化：root（materializeRoot）+ a + b（HookView 按需）。
    expect(concept.createCount, 3);

    // 无数据变化的强制重建 → 仍渲染物化实例（不重新 findFor/createHook）。
    await tester.tap(find.text('rebuild'));
    await tester.pump();
    expect(concept.createCount, 3);
    expect(find.text('marker-a'), findsOneWidget);
  });

  testWidgets('data 失效 → 仅命中节点 HookView 重建（定向）', (tester) async {
    final concept = _CountConcept(
      matchNodeIds: const <String>{'root', 'a', 'b'},
    );
    final host = _seed(root, concept: concept);
    await host.start(
      plugins: <Plugin>[_TestPlugin(concept: concept)],
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();
    final aBuilds = counterOf('a').builds;
    final bBuilds = counterOf('b').builds;

    // data 写命中 'a' → 只重建 a 的 HookView。
    await host.commandBus.dispatch<_DataTouchCommand, _TouchResult>(
      const _DataTouchCommand(nodeId: 'a'),
    );
    await tester.pump();

    expect(counterOf('a').builds, aBuilds + 1);
    expect(counterOf('b').builds, bBuilds); // 未命中不重建。
    expect(concept.createCount, 3); // 无重新物化。
  });

  testWidgets('structure 失效 → 树重挂：Hook 回收后重新物化', (tester) async {
    final concept = _CountConcept(
      matchNodeIds: const <String>{'root', 'a', 'b'},
    );
    final host = _seed(root, concept: concept);
    await host.start(
      plugins: <Plugin>[_TestPlugin(concept: concept)],
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();
    final before = concept.createCount;

    // structure 写命中 'a' → Hook 回收 → HookView 重新物化（不空洞）。
    await host.commandBus.dispatch<_StructureTouchCommand, _TouchResult>(
      const _StructureTouchCommand(nodeId: 'a'),
    );
    await tester.pump();

    expect(concept.createCount, before + 1); // 重新物化。
    expect(find.text('marker-a'), findsOneWidget); // 呈现不空洞。
    expect(find.text('marker-b'), findsOneWidget);
  });

  testWidgets('recycleOnDispose：卸载即回收物化 Hook（窗口化）', (tester) async {
    final concept = _CountConcept(
      matchNodeIds: const <String>{'root', 'a', 'b'},
    );
    final host = _seed(root, concept: concept);
    await host.start(
      plugins: <Plugin>[_TestPlugin(concept: concept)],
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );
    await tester.pumpWidget(_ToggleHarness(host: host, recycleOnDispose: true));
    await tester.pump();
    expect(host.uiManager.hookFor('a', 'sidebar'), isNotNull);

    // 卸载 HookView（切换显示）→ 物化 Hook 回收。
    await tester.tap(find.text('toggle'));
    await tester.pump();
    expect(host.uiManager.hookFor('a', 'sidebar'), isNull);
  });

  testWidgets('未 started：回退重派生路径（测试兼容）', (tester) async {
    final concept = _CountConcept(matchNodeIds: const <String>{'a'});
    final host = _seed(root, concept: concept);
    // 不 start()：直接向扩展点贡献 Concept（派生查询可用）。
    // owner = null（宿主贡献恒活跃——未加载插件视为非活跃，plugon 约定）。
    host.extensions
      ..registerExtensionPoint(conceptPoint)
      ..addContribution(conceptPoint, concept, ownerPluginId: null);

    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    expect(find.text('marker-a'), findsOneWidget);
    expect(find.text('marker-b'), findsNothing); // b 未命中 Concept → 兜底空。
    expect(concept.createCount, 1);
  });
}

/// 可卸载 HookView 的测试壳（toggle 切换显示）。
class _ToggleHarness extends StatefulWidget {
  const _ToggleHarness({required this.host, required this.recycleOnDispose});

  final HostRuntime host;
  final bool recycleOnDispose;

  @override
  State<_ToggleHarness> createState() => _ToggleHarnessState();
}

class _ToggleHarnessState extends State<_ToggleHarness> {
  bool _show = true;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Column(
        children: <Widget>[
          TextButton(
            onPressed: () => setState(() => _show = !_show),
            child: const Text('toggle'),
          ),
          if (_show)
            HookView(
              host: widget.host,
              nodeId: 'a',
              kind: 'sidebar',
              recycleOnDispose: widget.recycleOnDispose,
            ),
        ],
      ),
    ),
  );
}
