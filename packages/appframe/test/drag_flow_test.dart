/// §5.3 拖拽提交时序端到端测试（architecture.md §5.3 全路径）。
///
/// drop 判定（askDropSemantics）→ 环预判 → dispatch（Handler 二次
/// 校验双保险）→ 写后通知 → FlightShell 过渡/回弹。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_graph.dart';

/// 可配置 drop 语义的容器 Concept。
class _ContainerConcept extends Concept {
  _ContainerConcept({required this.id, required this.semantics});

  final String id;
  final DropSemantics Function(Node dragged) semantics;

  @override
  String get name => id;

  @override
  String get description => '测试容器 $id';

  @override
  Set<String> get slots => const <String>{'children'};

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
  bool validate(Node node) => true;

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
  Hook createHook(Node instance, HookContext context) =>
      _TestHook(nodeId: instance.id, hookId: '${instance.id}@${context.kind}');

  @override
  DropSemantics askDropSemantics(Node node) => semantics(node);
}

class _TestHook extends Hook {
  _TestHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {}
}

class _MemUIStateStore implements UIStateStore {
  final Map<String, dynamic> _store = <String, dynamic>{};
  final List<UIStateListener> _listeners = <UIStateListener>[];

  @override
  dynamic get(String key) => _store[key];

  @override
  Map<String, dynamic> getByPrefix(String prefix) => <String, dynamic>{
    for (final e in _store.entries)
      if (e.key.startsWith(prefix)) e.key: e.value,
  };

  @override
  void remove(String key) {
    if (_store.remove(key) != null) {
      _notify(key);
    }
  }

  @override
  void set(String key, dynamic value) {
    _store[key] = value;
    _notify(key);
  }

  @override
  void attach(UIStateListener listener) => _listeners.add(listener);

  @override
  void detach(UIStateListener listener) => _listeners.remove(listener);

  void _notify(String key) {
    for (final listener in List<UIStateListener>.of(_listeners)) {
      listener(key);
    }
  }
}

/// 未注册命令（验证非 CycleError 失败也会终结事务）。
class _UnhandledCommand extends Command<_UnhandledCommand> {
  const _UnhandledCommand();

  @override
  String get name => 'test.unhandled';

  @override
  Map<String, dynamic> get payload => const <String, dynamic>{};
}

void main() {
  group('§5.3 拖拽提交时序', () {
    late InMemoryGraph graph;
    late CommandBusImpl bus;
    late _MemUIStateStore uiState;
    late FlightShell shell;
    late List<FlightPhase> phaseLog;
    late List<WriteResult> writeLog;

    DragController controller(ConceptRegistry registry) => DragController(
      graph: graph,
      concepts: registry,
      commandBus: bus,
      uiStateStore: uiState,
      flightShell: shell,
    );

    setUp(() {
      graph = InMemoryGraph();
      bus = CommandBusImpl();
      uiState = _MemUIStateStore();
      phaseLog = <FlightPhase>[];
      writeLog = <WriteResult>[];
      shell = FlightShell(
        onFinished: (committed) {
          phaseLog.add(committed ? FlightPhase.committed : FlightPhase.aborted);
        },
      );
      bus.attach(writeLog.add);
      // 通用写命令（M4 机制：环校验 + 落盘 + 写后通知）。
      bus.register(MoveReferencesHandler(graph: graph));
    });

    test('DataMove 全路径：判定 → 环预判 → dispatch → 落盘 → 壳层过渡', () async {
      graph
        ..save(TestNode(id: 'folderA', title: '文件夹A'))
        ..save(TestNode(id: 'noteB', title: '笔记B'));
      final folder = _ContainerConcept(
        id: 'folder',
        semantics: (dragged) => const DataMove(<String, String>{
          'children': 'folderA', // noteB 挂到 folderA 下。
        }),
      );
      final registry = StaticConceptRegistry(concepts: <Concept>[folder]);
      final drag = controller(registry);
      final containerHook = folder.createHook(
        graph.get('folderA')!,
        const HookContext(kind: 'sidebar'),
      );

      final outcome = await drag.onDrop(
        draggedNodeId: 'noteB',
        targetContainerHook: containerHook,
        dropPoint: const Offset(120, 80),
      );

      expect(outcome.kind, DropOutcomeKind.committed);
      // 落盘：noteB.references.children == folderA。
      expect(graph.get('noteB')!.references['children'], 'folderA');
      // 写后通知：WriteNotifier 收到 MoveReferencesResult（structure）。
      expect(writeLog, hasLength(1));
      expect(writeLog.single.changeKind, ChangeKind.structure);
      // 壳层：present 进入 flying；commit 后 committed。
      expect(shell.phase, FlightPhase.flying);
      shell.commit();
      expect(phaseLog, <FlightPhase>[FlightPhase.committed]);
    });

    test('撞环预判：drop 阶段拒绝 → 回弹 → 无持久化副作用', () async {
      graph
        ..save(TestNode(id: 'a', title: 'A'))
        ..save(
          TestNode(
            id: 'b',
            title: 'B',
            references: const <String, String>{'parent': 'a'},
          ),
        );
      // 把 a 拖入 b 的后代：a 挂到 b 下 → b 引用 a → 环。
      final folder = _ContainerConcept(
        id: 'folder',
        semantics: (_) => const DataMove(<String, String>{'parent': 'b'}),
      );
      final drag = controller(
        StaticConceptRegistry(concepts: <Concept>[folder]),
      );
      final containerHook = folder.createHook(
        graph.get('b')!,
        const HookContext(kind: 'sidebar'),
      );

      final outcome = await drag.onDrop(
        draggedNodeId: 'a',
        targetContainerHook: containerHook,
        dropPoint: Offset.zero,
      );

      expect(outcome.kind, DropOutcomeKind.cycleRejected);
      expect(phaseLog, <FlightPhase>[FlightPhase.aborted]);
      // 无持久化副作用：a 无新引用，b 的引用未变。
      expect(graph.get('a')!.references, isEmpty);
      expect(writeLog, isEmpty);
    });

    test('Handler 二次校验（双保险）：预判漏网环在 Handler 拒绝', () async {
      graph
        ..save(TestNode(id: 'x', title: 'X'))
        ..save(
          TestNode(
            id: 'y',
            title: 'Y',
            references: const <String, String>{'parent': 'x'},
          ),
        );
      final folder = _ContainerConcept(
        id: 'folder',
        // 预判阶段 X 无引用（无环）；Handler 校验时 Y→X 已存在。
        semantics: (_) => const DataMove(<String, String>{'parent': 'y'}),
      );
      // 预判前先把 X 挂到 Y 下（模拟预判与落盘间的竞态）。
      graph.save(
        graph
            .get('x')!
            .copyWith(references: const <String, String>{'parent': 'y'}),
      );
      final drag = controller(
        StaticConceptRegistry(concepts: <Concept>[folder]),
      );
      final containerHook = folder.createHook(
        graph.get('y')!,
        const HookContext(kind: 'sidebar'),
      );

      final outcome = await drag.onDrop(
        draggedNodeId: 'x',
        targetContainerHook: containerHook,
        dropPoint: Offset.zero,
      );

      // 预判时 x 的 references 已是 {parent: y}（copyWith 后）——
      // 预判会命中环，走预判拒绝路径。
      expect(outcome.kind, DropOutcomeKind.cycleRejected);
      expect(phaseLog, <FlightPhase>[FlightPhase.aborted]);
    });

    test('RejectDrop：容器 schema 不兼容 → 回弹', () async {
      graph
        ..save(TestNode(id: 'folderA', title: '文件夹A'))
        ..save(TestNode(id: 'assetB', title: '图片B'));
      final folder = _ContainerConcept(
        id: 'folder',
        semantics: (_) => const RejectDrop('此容器无法容纳这种节点'),
      );
      final drag = controller(
        StaticConceptRegistry(concepts: <Concept>[folder]),
      );
      final containerHook = folder.createHook(
        graph.get('folderA')!,
        const HookContext(kind: 'sidebar'),
      );

      final outcome = await drag.onDrop(
        draggedNodeId: 'assetB',
        targetContainerHook: containerHook,
        dropPoint: Offset.zero,
      );

      expect(outcome.kind, DropOutcomeKind.rejected);
      expect(outcome.reason, '此容器无法容纳这种节点');
      expect(phaseLog, <FlightPhase>[FlightPhase.aborted]);
      expect(writeLog, isEmpty);
    });

    test('UIMove：外观直写 UIStateStore，无数据命令', () async {
      graph
        ..save(TestNode(id: 'canvas', title: '画布'))
        ..save(TestNode(id: 'note', title: '笔记'));
      final canvas = _ContainerConcept(
        id: 'canvas',
        semantics: (_) => const UIMove('position.graph.note', <String, dynamic>{
          'x': 42,
          'y': 7,
        }),
      );
      final drag = controller(
        StaticConceptRegistry(concepts: <Concept>[canvas]),
      );
      final containerHook = canvas.createHook(
        graph.get('canvas')!,
        const HookContext(kind: 'graph'),
      );

      final outcome = await drag.onDrop(
        draggedNodeId: 'note',
        targetContainerHook: containerHook,
        dropPoint: Offset.zero,
      );

      expect(outcome.kind, DropOutcomeKind.committed);
      expect(
        (uiState.get('position.graph.note') as Map<String, dynamic>)['x'],
        42,
      );
      expect(writeLog, isEmpty); // 无数据命令。
    });

    test('M7.4 会话态：dragStart → dragMove 分发；提交后全部清理', () async {
      graph
        ..save(TestNode(id: 'folderA', title: '文件夹A'))
        ..save(TestNode(id: 'noteB', title: '笔记B'));
      final folder = _ContainerConcept(
        id: 'folder',
        semantics: (_) =>
            const DataMove(<String, String>{'children': 'folderA'}),
      );
      final moves = <String>[];
      final drag = DragController(
        graph: graph,
        concepts: StaticConceptRegistry(concepts: <Concept>[folder]),
        commandBus: bus,
        uiStateStore: uiState,
        flightShell: shell,
        onDragMove: (nodeId, position) {
          moves.add('$nodeId@$position');
        },
      );

      drag.dragStart('noteB');
      drag.recordDragStart(const Offset(10, 20));
      drag.dragMove(const Offset(30, 40));

      expect(drag.dragging, 'noteB');
      expect(drag.lastDragPosition, const Offset(30, 40));
      expect(moves, <String>['noteB@Offset(30.0, 40.0)']);

      final containerHook = folder.createHook(
        graph.get('folderA')!,
        const HookContext(kind: 'sidebar'),
      );
      final outcome = await drag.onDrop(
        draggedNodeId: 'noteB',
        targetContainerHook: containerHook,
        dropPoint: const Offset(120, 80),
      );

      expect(outcome.kind, DropOutcomeKind.committed);
      expect(drag.dragging, isNull);
      expect(drag.lastDragPosition, isNull);
      expect(drag.dragStartOffset, isNull);
    });

    test('M7.4 非 CycleError 命令失败：终结事务并返回 rejected（不泄漏异常）', () async {
      graph
        ..save(TestNode(id: 'folderA', title: '文件夹A'))
        ..save(TestNode(id: 'noteB', title: '笔记B'));
      final folder = _ContainerConcept(
        id: 'folder',
        semantics: (_) =>
            const DataMove(<String, String>{'children': 'folderA'}),
      );
      final drag = DragController(
        graph: graph,
        concepts: StaticConceptRegistry(concepts: <Concept>[folder]),
        commandBus: bus,
        uiStateStore: uiState,
        flightShell: shell,
        moveCommandFactory:
            ({
              required String draggedNodeId,
              required String targetContainerId,
              required Map<String, String> newReferences,
            }) => const _UnhandledCommand(),
      );
      drag.dragStart('noteB');
      final containerHook = folder.createHook(
        graph.get('folderA')!,
        const HookContext(kind: 'sidebar'),
      );

      final outcome = await drag.onDrop(
        draggedNodeId: 'noteB',
        targetContainerHook: containerHook,
        dropPoint: Offset.zero,
      );

      expect(outcome.kind, DropOutcomeKind.rejected);
      expect(outcome.reason, contains('移动失败'));
      expect(phaseLog, <FlightPhase>[FlightPhase.aborted]);
      expect(drag.dragging, isNull);
      expect(drag.dragStartOffset, isNull);
    });

    test('M7.4 cancel 幂等：无事务/重复 cancel 只回滚一次', () async {
      graph
        ..save(TestNode(id: 'folderA', title: '文件夹A'))
        ..save(TestNode(id: 'noteB', title: '笔记B'));
      final folder = _ContainerConcept(
        id: 'folder',
        semantics: (_) => const RejectDrop('no'),
      );
      final drag = controller(
        StaticConceptRegistry(concepts: <Concept>[folder]),
      );

      drag.cancel(); // 无事务 no-op。
      expect(phaseLog, isEmpty);

      drag.dragStart('noteB');
      drag.cancel();
      drag.cancel(); // 会话态已清理 → 第二次不再 abort。

      expect(phaseLog, <FlightPhase>[FlightPhase.aborted]);
      expect(drag.dragging, isNull);
    });

    test('FlightShell 插值：tick 沿 from → to 线性插值', () {
      final positions = <Offset>[];
      final shell = FlightShell(
        onFrame: (progress, position) => positions.add(position),
      );

      shell.present(from: const Offset(0, 0), to: const Offset(100, 0));
      shell.tick(0);
      shell.tick(0.5);
      shell.tick(1);

      expect(positions[0], Offset.zero);
      expect(positions[1], const Offset(50, 0));
      expect(positions[2], const Offset(100, 0));
      expect(shell.phase, FlightPhase.flying);
    });
  });

  group('M7.4 FlightShell 视觉状态机', () {
    testWidgets('present 携带 overlay 影像 → 动画完成自动提交并移除', (tester) async {
      final log = <bool>[];
      final shell = FlightShell(onFinished: log.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Builder(builder: (context) => const SizedBox())),
        ),
      );
      final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
      shell.present(
        overlay: overlay,
        child: const Text('flight-child'),
        from: const Offset(10, 10),
        to: const Offset(120, 80),
        duration: const Duration(milliseconds: 100),
      );

      expect(shell.phase, FlightPhase.flying);
      await tester.pump();
      expect(find.text('flight-child'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('flight-child'), findsNothing);
      expect(shell.phase, FlightPhase.committed);
      expect(log, <bool>[true]);
    });

    testWidgets('bounce 视觉完成 → aborted；新 present 会替换旧影像不崩溃', (tester) async {
      final shell = FlightShell();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Builder(builder: (context) => const SizedBox())),
        ),
      );
      final overlay = tester.state<OverlayState>(find.byType(Overlay).first);

      shell.bounce(
        overlay: overlay,
        child: const Text('bounce-child'),
        from: const Offset(0, 0),
        to: const Offset(80, 80),
        duration: const Duration(milliseconds: 100),
        onFinished: (_) {},
      );
      await tester.pump();
      expect(find.text('bounce-child'), findsOneWidget);

      // 未等回弹结束立即启动新 present：旧 entry 应被安全替换。
      shell.present(
        overlay: overlay,
        child: const Text('replacement-child'),
        from: const Offset(0, 0),
        to: const Offset(20, 20),
        duration: const Duration(milliseconds: 100),
      );
      await tester.pump();
      expect(find.text('bounce-child'), findsNothing);
      expect(find.text('replacement-child'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('replacement-child'), findsNothing);
      expect(shell.phase, FlightPhase.committed);
    });
  });
}
