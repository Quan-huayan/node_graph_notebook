/// 工具栏拖拽建按钮测试（M7.3 Flowing UI）：
/// CreateToolbarButtonCommand 落盘/幂等、targeted 动作注册、
/// ToolbarActionsRow 接收拖拽 → 按钮节点创建。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon.dart';

/// 种子：toolbar-root + 按钮节点 + 源节点（note/AI）。
Future<HostRuntime> seed(Directory root) async {
  final host = HostRuntime(dataRoot: root);
  final now = DateTime.now();
  <StoredNode>[
    StoredNode(
      id: 'toolbar-root',
      title: '工具栏',
      metadata: const <String, dynamic>{'kind': 'toolbar-root'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'toolbar-settings',
      title: '设置',
      metadata: const <String, dynamic>{
        'kind': 'toolbar',
        'icon': 'settings',
        'action': 'settings.open',
      },
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(id: 'noteA', title: '笔记A', createdAt: now, updatedAt: now),
    StoredNode(
      id: 'aiNode',
      title: 'AI 助手',
      metadata: const <String, dynamic>{'kind': 'ai'},
      createdAt: now,
      updatedAt: now,
    ),
  ].forEach(host.graph.save);
  await host.start(plugins: <Plugin>[], rootNodeId: 'toolbar-root');
  return host;
}

/// 测试壳：AppBar 工具栏（HookView toolbar-root）+ body 源 Draggable。
class _Harness extends StatelessWidget {
  const _Harness({required this.host});

  final HostRuntime host;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        actions: [
          HookView(host: host, nodeId: 'toolbar-root', kind: 'toolbar-root'),
        ],
      ),
      body: Center(
        child: Draggable<String>(
          data: 'noteA',
          feedback: const Material(
            color: Colors.transparent,
            child: Text('笔记A'),
          ),
          child: const Text('拖我'),
        ),
      ),
    ),
  );
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_toolbar');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  test('CreateToolbarButtonCommand：落盘 + metadata + 幂等', () async {
    final host = await seed(root);
    final result = await host.commandBus
        .dispatch<CreateToolbarButtonCommand, CreateToolbarButtonResult>(
          CreateToolbarButtonCommand(sourceId: 'noteA'),
        );
    expect(result.buttonId, 'toolbar-open-noteA');

    final button = host.graph.get('toolbar-open-noteA')!;
    expect(button.metadata['kind'], 'toolbar');
    expect(button.metadata['icon'], 'open_in_new');
    expect(button.metadata['action'], 'node.open');
    expect(button.metadata['target'], 'noteA');
    expect(button.metadata['tooltip'], '笔记A');

    // 幂等：再建 → 同一 id，不重复创建。
    await host.commandBus
        .dispatch<CreateToolbarButtonCommand, CreateToolbarButtonResult>(
          CreateToolbarButtonCommand(sourceId: 'noteA'),
        );
    expect(host.graph.get('toolbar-open-noteA'), isNotNull);

    // AI 源 → smart_toy 图标。
    await host.commandBus
        .dispatch<CreateToolbarButtonCommand, CreateToolbarButtonResult>(
          CreateToolbarButtonCommand(sourceId: 'aiNode'),
        );
    expect(
      host.graph.get('toolbar-open-aiNode')!.metadata['icon'],
      'smart_toy',
    );

    // 源节点零变更（L0 不被污染）。
    expect(host.graph.get('noteA')!.references, isEmpty);
  });

  test('ToolbarActionRegistry：targeted 注册/查找 + unregisterAll', () async {
    final host = await seed(root);
    final registry = host.toolbarActions;
    String? opened;
    registry.registerTargeted('node.open', (ctx, targetId) {
      opened = targetId;
    });
    expect(registry.lookupTargeted('node.open'), isNotNull);
    expect(registry.lookupTargeted('missing'), isNull);
    // 普通注册与 targeted 并存不串扰。
    var plain = 0;
    registry.register('plain.action', (_) => plain++);
    expect(registry.lookup('plain.action'), isNotNull);
    registry.unregisterAll();
    expect(registry.lookupTargeted('node.open'), isNull);
    expect(registry.lookup('plain.action'), isNull);
    expect(opened, isNull);
  });

  test('语义服务缺省注册：返回 null（默认语义不抛）', () async {
    final host = await seed(root);
    final semantics = host.serviceProvider.get<SidebarDropSemantics>();
    final command = semantics(
      draggedNodeId: 'noteA',
      targetContainerId: 'root',
    );
    expect(command, isNull);
    final toolbarSemantics = host.serviceProvider.get<ToolbarDropSemantics>();
    expect(toolbarSemantics(draggedNodeId: 'noteA'), isNull);
  });

  testWidgets('拖节点到工具栏 → 按钮节点创建（ToolbarActionsRow 接收）', (tester) async {
    final host = await seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    expect(host.graph.get('toolbar-open-noteA'), isNull);
    final source = find.text('拖我');
    final target = find.byType(ToolbarActionsRow);
    await tester.drag(
      source,
      tester.getCenter(target) - tester.getCenter(source),
    );
    await tester.pumpAndSettle();
    // SnackBar 定时器清理。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final button = host.graph.get('toolbar-open-noteA');
    expect(button, isNotNull);
    expect(button!.metadata['target'], 'noteA');
    // 新按钮出现在工具栏（容器枚举自动）。
    expect(find.byTooltip('笔记A'), findsOneWidget);
  });
}
