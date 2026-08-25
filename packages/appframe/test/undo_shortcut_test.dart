/// Ctrl+Z 撤销快捷键测试（P1-2，03 §四 契约的 UI 接线）：
///
/// NotebookApp Shortcuts → Actions → host.undoManager.undo() 全链路——
/// 键事件触发撤销，写后通知刷新 UI。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试更新命令（appframe 不依赖插件命令——最小 DTO + Handler）。
class _TestUpdateCommand extends Command<_TestUpdateCommand> {
  const _TestUpdateCommand({required this.nodeId, this.title});

  final String nodeId;
  final String? title;

  @override
  String get name => 'test.update';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{'nodeId': nodeId};
}

class _TestUpdateResult implements WriteResult {
  const _TestUpdateResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.data;

  @override
  final Command? inverse;
}

class _TestUpdateHandler
    extends CommandHandler<_TestUpdateCommand, _TestUpdateResult> {
  _TestUpdateHandler(this.graph);

  final Graph graph;

  @override
  Type get commandType => _TestUpdateCommand;

  @override
  Future<_TestUpdateResult> handle(_TestUpdateCommand command) async {
    final node = graph.get(command.nodeId);
    if (node == null) {
      throw StateError('不存在: ${command.nodeId}');
    }
    final previous = node.title;
    graph.save(node.copyWith(title: command.title));
    return _TestUpdateResult(
      affectedNodeIds: <String>{command.nodeId},
      inverse: _TestUpdateCommand(nodeId: command.nodeId, title: previous),
    );
  }
}

void main() {
  testWidgets('Ctrl+Z → UndoManager.undo 恢复标题；Ctrl+Y → redo', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('ngn_undo_ui');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    host.graph
      ..save(StoredNode(id: 'root', title: '根', createdAt: now, updatedAt: now))
      ..save(
        StoredNode(id: 'noteA', title: '旧标题', createdAt: now, updatedAt: now),
      );
    host.commandBus.register(_TestUpdateHandler(host.graph));

    await tester.pumpWidget(NotebookApp(host: host, rootNodeId: 'root'));
    await tester.pump();

    // 写命令 → inverse 入撤销栈。
    await host.commandBus.dispatch<_TestUpdateCommand, _TestUpdateResult>(
      const _TestUpdateCommand(nodeId: 'noteA', title: '新标题'),
    );
    expect(host.graph.get('noteA')!.title, '新标题');
    expect(host.undoManager.canUndo, isTrue);

    // Ctrl+Z。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(host.graph.get('noteA')!.title, '旧标题');
    expect(host.undoManager.canRedo, isTrue);

    // Ctrl+Y 重做。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(host.graph.get('noteA')!.title, '新标题');
  });

  testWidgets('Ctrl+N → ToolbarActionRegistry note.create 动作（M8：意图归壳层，实现归插件）', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('ngn_new_note');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    host.graph.save(
      StoredNode(id: 'root', title: '根', createdAt: now, updatedAt: now),
    );
    // M8：不再注入组合根回调——测试用插件等价物注册动作。
    var invoked = 0;
    host.toolbarActions.register('note.create', (_) => invoked++);
    await tester.pumpWidget(NotebookApp(host: host, rootNodeId: 'root'));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(invoked, 1);
  });

  testWidgets('Ctrl+F → ShellSignals 搜索信号（侧边栏 tab 切换通道）', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('ngn_search_key');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    host.graph.save(
      StoredNode(id: 'root', title: '根', createdAt: now, updatedAt: now),
    );
    var signaled = 0;
    host.shellSignals.addListener(() => signaled++);
    await tester.pumpWidget(NotebookApp(host: host, rootNodeId: 'root'));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(signaled, 1);
  });
}
