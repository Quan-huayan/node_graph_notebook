import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command.dart';
import 'package:node_graph_notebook/core/commands/command_context.dart';
import 'package:node_graph_notebook/core/commands/command_handler.dart';
import 'package:node_graph_notebook/core/commands/command_handler_registry.dart';

// 测试命令
class TestCommand extends Command<String> {
  @override
  String get name => 'TestCommand';

  @override
  String get description => 'Test command';

  @override
  bool get isUndoable => false;

  @override
  Future<CommandResult<String>> execute(CommandContext context) async {
    return CommandResult.success('Test result');
  }

  @override
  Future<void> undo(covariant CommandContext context) async {
    throw UnsupportedError('Not undoable');
  }
}

// 测试命令处理器
class TestCommandHandler extends CommandHandler<TestCommand> {
  @override
  Future<CommandResult> execute(TestCommand command, CommandContext context) async {
    return CommandResult.success('Test result');
  }
}

void main() {
  late CommandHandlerRegistry registry;

  setUp(() {
    registry = CommandHandlerRegistry();
  });

  test('should register and get command handler', () {
    final handler = TestCommandHandler();
    registry.register(handler, TestCommand);

    final retrievedHandler = registry.getHandler(TestCommand);
    expect(retrievedHandler, equals(handler));
  });

  test('should return null for unregistered command type', () {
    final handler = registry.getHandler(TestCommand);
    expect(handler, isNull);
  });

  test('should register multiple handlers', () {
    final handler1 = TestCommandHandler();
    registry.register(handler1, TestCommand);

    expect(registry.size, equals(1));
  });

  test('should override existing handler for same command type', () {
    final handler1 = TestCommandHandler();
    final handler2 = TestCommandHandler();

    registry.register(handler1, TestCommand);
    registry.register(handler2, TestCommand);

    final retrievedHandler = registry.getHandler(TestCommand);
    expect(retrievedHandler, equals(handler2));
  });

  test('should unregister handler', () {
    final handler = TestCommandHandler();
    registry.register(handler, TestCommand);

    expect(registry.size, equals(1));

    registry.unregister(TestCommand);
    expect(registry.size, equals(0));
    expect(registry.getHandler(TestCommand), isNull);
  });

  test('should clear all handlers', () {
    final handler = TestCommandHandler();
    registry.register(handler, TestCommand);

    expect(registry.size, equals(1));

    registry.clear();
    expect(registry.size, equals(0));
    expect(registry.getHandler(TestCommand), isNull);
  });

  test('should check if handler exists', () {
    final handler = TestCommandHandler();
    registry.register(handler, TestCommand);

    expect(registry.contains(TestCommand), isTrue);
    expect(registry.contains(String), isFalse);
  });

  test('should register multiple handlers in bulk', () {
    final handler1 = TestCommandHandler();
    final handlers = {
      TestCommand: handler1,
    };

    registry.registerAll(handlers);
    expect(registry.size, equals(1));
    expect(registry.getHandler(TestCommand), equals(handler1));
  });
}
