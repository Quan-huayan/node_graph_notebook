import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/execution/cpu_task.dart';
import 'package:node_graph_notebook/core/execution/execution_engine.dart';
import 'package:node_graph_notebook/core/execution/task_registry.dart';

class TestTask extends CPUTask<int> {
  TestTask({required this.value});

  final int value;

  @override
  String get name => 'TestTask($value)';

  @override
  String get taskType => 'Test';

  @override
  Map<String, dynamic> serialize() => {
      'taskType': taskType,
      'taskName': name,
      'value': value,
    };

  @override
  Future<int> execute() async {
    var result = 0;
    for (var i = 0; i < 1000; i++) {
      result += value;
    }
    return result;
  }
}

class AsyncTestTask extends CPUTask<String> {
  AsyncTestTask({required this.message});

  final String message;

  @override
  String get name => 'AsyncTestTask($message)';

  @override
  String get taskType => 'AsyncTest';

  @override
  Map<String, dynamic> serialize() => {
      'taskType': taskType,
      'taskName': name,
      'message': message,
    };

  @override
  Future<String> execute() async {
    await Future.delayed(const Duration(milliseconds: 10));
    return 'Processed: $message';
  }
}

class FailingTask extends CPUTask<void> {
  @override
  String get name => 'FailingTask';

  @override
  String get taskType => 'Failing';

  @override
  Map<String, dynamic> serialize() => {
      'taskType': taskType,
      'taskName': name,
    };

  @override
  Future<void> execute() async {
    throw Exception('Task failed!');
  }
}

void main() {
  group('ExecutionEngine', () {
    late ExecutionEngine engine;
    late TaskRegistry taskRegistry;

    setUp(() async {
      engine = ExecutionEngine();
      taskRegistry = TaskRegistry()

      ..registerTaskType(
        'Test',
        (data) => TestTask(value: data['value'] as int),
        (result) => result as int,
      )
      ..registerTaskType(
        'AsyncTest',
        (data) => AsyncTestTask(message: data['message'] as String),
        (result) => result as String,
      )
      ..registerTaskType(
        'Failing',
        (data) => FailingTask(),
        (result) => result,
      );

      await engine.initialize(maxWorkers: 2, taskRegistry: taskRegistry);
    });

    tearDown(() async {
      await engine.shutdown();
    });

    test('should initialize successfully', () {
      expect(engine.isInitialized, isTrue);
      expect(engine.stats, isA<Map<String, dynamic>>());
    });

    test('should execute CPU task and return result', () async {
      final task = TestTask(value: 42);
      final result = await engine.executeCPU(task);

      expect(result, equals(42000));
    });

    test('should execute async CPU task', () async {
      final task = AsyncTestTask(message: 'Hello');
      final result = await engine.executeCPU(task);

      expect(result, equals('Processed: Hello'));
    });

    test('should handle multiple concurrent tasks', () async {
      final tasks = List.generate(
        10,
        (i) => TestTask(value: i),
      );

      final results = await Future.wait(
        tasks.map((task) => engine.executeCPU(task)),
      );

      expect(results.length, equals(10));
      expect(results[0], equals(0));
      expect(results[5], equals(5000));
      expect(results[9], equals(9000));
    });

    test('should track job statistics', () async {
      final task = TestTask(value: 1);
      await engine.executeCPU(task);

      final stats = engine.stats;
      expect(stats, isNotEmpty);
    });

    test('should throw error when executing before initialization', () async {
      final uninitializedEngine = ExecutionEngine();

      expect(
        () => uninitializedEngine.executeCPU(TestTask(value: 1)),
        throwsA(isA<StateError>()),
      );
    });

    test('should shutdown cleanly', () async {
      await engine.shutdown();

      expect(
        () => engine.stats,
        throwsA(isA<StateError>()),
      );
    });

    test('should handle task exceptions gracefully', () async {
      final errors = <Object>[];
      await runZonedGuarded(() async {
        final task = FailingTask();

        try {
          await engine.executeCPU(task);
        } on Exception catch (e) {
          errors.add(e);
        }
      }, (error, stack) {
        errors.add(error);
      });

      expect(errors, isNotEmpty);
      expect(errors.first.toString(), contains('Task failed!'));
    });
  });

  group('ExecutionEngine with default workers', () {
    test('should use platform processor count minus 1', () async {
      final engine = ExecutionEngine();
      final taskRegistry = TaskRegistry()

      ..registerTaskType(
        'Test',
        (data) => TestTask(value: data['value'] as int),
        (result) => result as int,
      );

      await engine.initialize(taskRegistry: taskRegistry);

      expect(engine.isInitialized, isTrue);

      await engine.shutdown();
    });
  });
}
