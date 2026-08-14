/// UndoManager 测试（P1-2，03 §四 撤销契约落地）：
///
/// 栈行为（record/undo/redo/上限/清空）+ PluginCommandBus 集成
/// （dispatch 自动 record；undo 经 executeRaw 不重复入栈——否则撤销
/// 会把对偶命令的结果再压回栈，撤销失效）。
library;

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon.dart';

/// 测试命令（inverse = 同类型反序列标记）。
class _TestCommand extends Command<_TestCommand> {
  const _TestCommand(this.id);

  final String id;

  @override
  String get name => 'test.command';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{'id': id};
}

/// 测试写结果（inverse 由构造注入）。
class _TestResult implements WriteResult {
  const _TestResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.data;

  @override
  final Command? inverse;
}

/// 记录调用序列的测试 Handler。
class _LogHandler extends CommandHandler<_TestCommand, _TestResult> {
  _LogHandler(this.log);

  final List<String> log;

  @override
  Type get commandType => _TestCommand;

  @override
  Future<_TestResult> handle(_TestCommand command) async {
    log.add(command.id);
    return _TestResult(
      affectedNodeIds: <String>{command.id},
      inverse: _TestCommand('${command.id}-inverse'),
    );
  }
}

/// 固定 null inverse 的 Handler（显式不可撤销）。
class _IrreversibleHandler extends CommandHandler<_TestCommand, _TestResult> {
  @override
  Type get commandType => _TestCommand;

  @override
  Future<_TestResult> handle(_TestCommand command) async =>
      _TestResult(affectedNodeIds: <String>{command.id});
}

void main() {
  test('record：inverse 入栈；null inverse 跳过；新写清空 redo', () async {
    final log = <String>[];
    final bus = PluginCommandBus(extensions: ExtensionRegistry());
    final manager = UndoManager(dispatchRaw: bus.executeRaw);
    bus.undoManager = manager;
    bus.register(_LogHandler(log));

    await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand('a'));
    expect(manager.canUndo, isTrue);

    // 新写清空 redo（标准撤销语义）。
    await manager.undo();
    expect(manager.canRedo, isTrue);
    await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand('b'));
    expect(manager.canRedo, isFalse);

    // 显式不可撤销（inverse null）→ 不入栈：栈深不变。
    bus.register(_IrreversibleHandler());
    final canUndoBefore = manager.canUndo;
    await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand('c'));
    expect(manager.canUndo, canUndoBefore);
  });

  test('undo/redo 往返：undo 经 executeRaw（不重复 record）', () async {
    final log = <String>[];
    final bus = PluginCommandBus(extensions: ExtensionRegistry());
    final manager = UndoManager(dispatchRaw: bus.executeRaw);
    bus.undoManager = manager;
    bus.register(_LogHandler(log));

    await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand('a'));
    expect(manager.canUndo, isTrue);

    await manager.undo();
    expect(log, <String>['a', 'a-inverse']);
    // 关键：撤销不把自己重新压回撤销栈。
    expect(manager.canUndo, isFalse);
    expect(manager.canRedo, isTrue);

    await manager.redo();
    expect(log, <String>['a', 'a-inverse', 'a-inverse-inverse']);
    expect(manager.canUndo, isTrue);
    expect(manager.canRedo, isFalse);
  });

  test('栈上限：超出丢最旧', () async {
    final bus = PluginCommandBus(extensions: ExtensionRegistry());
    final manager = UndoManager(dispatchRaw: bus.executeRaw, limit: 2);
    bus.undoManager = manager;
    bus.register(_LogHandler(<String>[]));

    await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand('a'));
    await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand('b'));
    await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand('c'));

    // 最旧的 a 被丢弃：两次 undo → 空栈。
    await manager.undo();
    await manager.undo();
    expect(manager.canUndo, isFalse);
  });

  test('空栈 undo/redo no-op；clear 清空两栈', () async {
    final bus = PluginCommandBus(extensions: ExtensionRegistry());
    final manager = UndoManager(dispatchRaw: bus.executeRaw);
    bus.undoManager = manager;
    bus.register(_LogHandler(<String>[]));

    await manager.undo(); // no-op。
    await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand('a'));
    await manager.undo();
    manager.clear();
    expect(manager.canUndo, isFalse);
    expect(manager.canRedo, isFalse);
  });
}
