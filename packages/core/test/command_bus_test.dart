/// CommandBusImpl 契约测试（03 §四：路由 + 写后通知单播桥）。
library;

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestCommand extends Command<_TestCommand> {
  const _TestCommand();

  @override
  String get name => 'test.command';

  @override
  Map<String, dynamic> get payload => const <String, dynamic>{};
}

class _TestResult implements WriteResult {
  const _TestResult();

  @override
  Set<String> get affectedNodeIds => const <String>{'n1'};

  @override
  ChangeKind get changeKind => ChangeKind.data;

  @override
  Command? get inverse => null;
}

class _TestHandler extends CommandHandler<_TestCommand, _TestResult> {
  int handleCount = 0;

  @override
  Future<_TestResult> handle(_TestCommand command) async {
    handleCount++;
    return const _TestResult();
  }

  @override
  Type get commandType => _TestCommand;
}

void main() {
  group('CommandBusImpl（03 §四）', () {
    test('dispatch 路由到注册的 Handler 并返回 WriteResult', () async {
      final bus = CommandBusImpl();
      final handler = _TestHandler();
      bus.register(handler);

      final result = await bus.dispatch<_TestCommand, _TestResult>(
        const _TestCommand(),
      );

      expect(handler.handleCount, 1);
      expect(result.affectedNodeIds, <String>{'n1'});
      expect(result.changeKind, ChangeKind.data);
    });

    test('写后通知：dispatch 完成后 listeners 收到 WriteResult（单播桥）', () async {
      final bus = CommandBusImpl();
      bus.register(_TestHandler());
      final received = <WriteResult>[];
      bus.attach(received.add);

      await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand());

      expect(received, hasLength(1));
      expect(received.single.changeKind, ChangeKind.data);
    });

    test('detach 后不再通知', () async {
      final bus = CommandBusImpl();
      bus.register(_TestHandler());
      final received = <WriteResult>[];
      final listener = received.add;
      bus.attach(listener);
      bus.detach(listener);

      await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand());

      expect(received, isEmpty);
    });

    test('未注册命令 → StateError（配置错误，快速失败）', () async {
      final bus = CommandBusImpl();

      expect(
        () => bus.dispatch<_TestCommand, _TestResult>(const _TestCommand()),
        throwsA(isA<StateError>()),
      );
    });

    test('按命令运行时类型路由：不同命令类互不干扰', () async {
      final bus = CommandBusImpl();
      final handler = _TestHandler();
      bus.register(handler);
      // 同类命令的不同实例仍路由到同一 handler。
      await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand());
      await bus.dispatch<_TestCommand, _TestResult>(const _TestCommand());

      expect(handler.handleCount, 2);
    });
  });
}
