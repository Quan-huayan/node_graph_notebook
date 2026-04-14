import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/cqrs/commands/command_bus.dart';
import 'package:node_graph_notebook/core/cqrs/commands/models/command.dart';
import 'package:node_graph_notebook/core/cqrs/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/cqrs/commands/models/command_handler.dart';
import 'package:node_graph_notebook/core/cqrs/commands/models/middleware.dart';

// 模拟命令类
class MockCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async => CommandResult.success();

  @override
  String get name => '模拟命令';

  @override
  String get description => '用于测试的模拟命令';
}

// 模拟命令处理器
class MockCommandHandler extends CommandHandler<MockCommand> {
  @override
  Future<CommandResult> execute(MockCommand command, CommandContext context) async => CommandResult.success();
}

// 模拟中间件
class MockMiddleware extends CommandMiddleware {
  int beforeCount = 0;
  int afterCount = 0;

  @override
  Future<void> processBefore(Command command, CommandContext context) async => beforeCount++;

  @override
  Future<void> processAfter(Command command, CommandContext context, CommandResult result) async => afterCount++;
}

// 用于测试的错误命令
class ErrorCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async => throw Exception('Command error');

  @override
  String get name => '错误命令';

  @override
  String get description => '抛出错误的命令';
}

// 错误命令处理器
class ErrorCommandHandler extends CommandHandler<ErrorCommand> {
  @override
  Future<CommandResult> execute(ErrorCommand command, CommandContext context) async => command.execute(context);
}

// 可撤销命令
class UndoableCommand extends Command<dynamic> {
  bool undone = false;

  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async => CommandResult.success();

  @override
  Future<void> undo(CommandContext context) async => undone = true;

  @override
  String get name => '可撤销命令';

  @override
  String get description => '可以撤销的命令';
}

// 不可撤销命令
class NonUndoableCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async => CommandResult.success();

  @override
  bool get isUndoable => false;

  @override
  String get name => '不可撤销命令';

  @override
  String get description => '不能撤销的命令';
}

// 撤销错误命令
class UndoErrorCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async => CommandResult.success();

  @override
  Future<void> undo(CommandContext context) async => throw Exception('Undo error');

  @override
  String get name => '撤销错误命令';

  @override
  String get description => '在撤销时抛出错误的命令';
}

void main() {
  group('CommandBus', () {
    late CommandBus commandBus;

    setUp(() {
      commandBus = CommandBus();
    });

    tearDown(() {
      commandBus.dispose();
    });

    test('应该成功注册和分发命令', () async {
      // 注册处理器
      commandBus.registerHandler(MockCommandHandler(), MockCommand);

      // 分发命令
      final result = await commandBus.dispatch(MockCommand());

      expect(result.isSuccess, true);
    });

    test('应该在未注册处理器时抛出错误', () async {
      final result = await commandBus.dispatch(MockCommand());
      expect(result.isSuccess, false);
      expect(result.error, contains('CommandHandlerNotFoundException'));
    });

    test('应该执行中间件', () async {
      final middleware = MockMiddleware();
      commandBus
        ..addMiddleware(middleware)
        ..registerHandler(MockCommandHandler(), MockCommand);

      await commandBus.dispatch(MockCommand());

      expect(middleware.beforeCount, 1);
      expect(middleware.afterCount, 1);
    });

    test('应该处理命令执行错误', () async {
      commandBus.registerHandler(ErrorCommandHandler(), ErrorCommand);

      final result = await commandBus.dispatch(ErrorCommand());
      expect(result.isSuccess, false);
      expect(result.error, contains('Command error'));
    });

    test('如果可撤销应该撤销命令', () async {
      final command = UndoableCommand();
      commandBus.registerHandler(MockCommandHandler(), UndoableCommand);

      await commandBus.dispatch(command);
      await commandBus.undo(command);

      expect(command.undone, true);
    });

    test('在撤销不可撤销命令时应该抛出错误', () async {
      final command = NonUndoableCommand();
      commandBus.registerHandler(MockCommandHandler(), NonUndoableCommand);

      await commandBus.dispatch(command);
      expect(() => commandBus.undo(command), throwsA(isA<UnsupportedError>()));
    });

    test('应该处理撤销错误', () async {
      final command = UndoErrorCommand();
      commandBus.registerHandler(MockCommandHandler(), UndoErrorCommand);

      await commandBus.dispatch(command);
      expect(() => commandBus.undo(command), throwsA(isA<Exception>()));
    });

    test('应该释放资源', () {
      commandBus.dispose();
      expect(() => commandBus.registerHandler(MockCommandHandler(), MockCommand), throwsA(isA<StateError>()));
    });

    test('应该发出命令事件', () async {
      final events = <CommandEvent>[];
      commandBus.commandStream.listen(events.add);

      commandBus.registerHandler(MockCommandHandler(), MockCommand);
      await commandBus.dispatch(MockCommand());

      expect(events.length, greaterThanOrEqualTo(1)); // 至少应该有 CommandStarted
      expect(events[0], isA<CommandStarted>());
      // 检查是否有 CommandSucceeded 或 CommandFailed
      if (events.length > 1) {
        expect(events[1], isA<CommandSucceeded>());
      }
    });
  });
}
