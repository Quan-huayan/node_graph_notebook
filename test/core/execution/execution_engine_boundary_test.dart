import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/execution/cpu_task.dart';
import 'package:node_graph_notebook/core/execution/execution_engine.dart';
import 'package:node_graph_notebook/core/execution/task_registry.dart';

/// 简单测试任务
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
  Future<int> execute() async => value * 1000;
}

/// 递归计算任务 - 用于测试CPU密集
class RecursiveTask extends CPUTask<int> {
  RecursiveTask({required this.n});

  final int n;

  @override
  String get name => 'RecursiveTask($n)';

  @override
  String get taskType => 'Recursive';

  @override
  Map<String, dynamic> serialize() => {
      'taskType': taskType,
      'taskName': name,
      'n': n,
    };

  int _fibonacci(int n) {
    if (n <= 1) return n;
    return _fibonacci(n - 1) + _fibonacci(n - 2);
  }

  @override
  Future<int> execute() async => _fibonacci(n);
}

void main() {
  group('ExecutionEngine Boundary Tests', () {
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
          'Recursive',
          (data) => RecursiveTask(n: data['n'] as int),
          (result) => result as int,
        );

      await engine.initialize(maxWorkers: 2, taskRegistry: taskRegistry);
    });

    tearDown(() async {
      await engine.shutdown();
    });

    group('并发边界测试', () {
      test('应该处理大量并发任务而不死锁', () async {
        const taskCount = 20;
        final tasks = List.generate(
          taskCount,
          (i) => TestTask(value: i),
        );

        final stopwatch = Stopwatch()..start();
        final results = await Future.wait(
          tasks.map((task) => engine.executeCPU(task)),
        );
        stopwatch.stop();

        expect(results.length, taskCount);
        expect(results.every((r) => r >= 0), true);
        // 20个任务应该能在合理时间内完成
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('应该处理快速连续任务提交', () async {
        const iterations = 50;
        final results = <int>[];

        for (var i = 0; i < iterations; i++) {
          final result = await engine.executeCPU(RecursiveTask(n: 10));
          results.add(result);
        }

        expect(results.length, iterations);
        expect(results.every((r) => r == 55), true); // fib(10) = 55
      });

      test('应该并发处理混合任务类型', () async {
        final futures = <Future<dynamic>>[
          engine.executeCPU(TestTask(value: 1)),
          engine.executeCPU(RecursiveTask(n: 15)),
          engine.executeCPU(TestTask(value: 2)),
          engine.executeCPU(RecursiveTask(n: 10)),
          engine.executeCPU(TestTask(value: 3)),
        ];

        final results = await Future.wait(futures);

        expect(results[0], equals(1000));
        expect(results[1], equals(610)); // fib(15) = 610
        expect(results[2], equals(2000));
        expect(results[3], equals(55)); // fib(10) = 55
        expect(results[4], equals(3000));
      });
    });

    group('资源限制边界测试', () {
      test('应该处理深度递归而不栈溢出', () async {
        // fib(20) = 6765, 需要大量递归调用
        final task = RecursiveTask(n: 20);
        final result = await engine.executeCPU(task);

        expect(result, equals(6765));
      });

      test('应该处理执行时间不同的任务', () async {
        final tasks = [
          TestTask(value: 1),
          RecursiveTask(n: 15),
          TestTask(value: 2),
          RecursiveTask(n: 10),
          TestTask(value: 3),
        ];

        final stopwatch = Stopwatch()..start();
        final results = await Future.wait(
          tasks.map((task) => engine.executeCPU(task)),
        );
        stopwatch.stop();

        expect(results.length, 5);
        // 总时间应该小于串行执行时间
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      });
    });

    group('引擎状态边界测试', () {
      test('应该支持关闭后重新初始化', () async {
        await engine.shutdown();

        // 重新初始化
        await engine.initialize(maxWorkers: 2, taskRegistry: taskRegistry);

        final result = await engine.executeCPU(RecursiveTask(n: 10));
        expect(result, equals(55));
      });

      test('应该优雅地处理多次关闭调用', () async {
        await engine.shutdown();
        await engine.shutdown(); // 第二次调用不应该抛出错误

        expect(engine.isInitialized, false);
      });

      test('关闭后应该拒绝任务', () async {
        await engine.shutdown();

        expect(
          () => engine.executeCPU(RecursiveTask(n: 10)),
          throwsA(isA<StateError>()),
        );
      });

      test('初始化之前执行应该抛出错误', () {
        final uninitializedEngine = ExecutionEngine();

        expect(
          () => uninitializedEngine.executeCPU(TestTask(value: 1)),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('TaskRegistry边界测试', () {
      test('应该处理任务类型覆盖', () {
        final registry = TaskRegistry();

        // 注册任务类型
        registry.registerTaskType(
          'CustomTask',
          (data) => TestTask(value: 10),
          (result) => result as int,
        );

        // 覆盖注册
        registry.registerTaskType(
          'CustomTask',
          (data) => TestTask(value: 20),
          (result) => result as int,
        );

        // 应该使用新的注册
        final factory = registry.getFactory('CustomTask');
        expect(factory, isNotNull);
      });

      test('应该返回正确的统计信息', () {
        final stats = taskRegistry.statistics;

        expect(stats['totalTaskTypes'], equals(2));
        expect(stats['taskTypes'], contains('Test'));
        expect(stats['taskTypes'], contains('Recursive'));
      });

      test('应该处理空注册表', () {
        final emptyRegistry = TaskRegistry();

        expect(emptyRegistry.taskTypes, isEmpty);
        expect(emptyRegistry.statistics['totalTaskTypes'], equals(0));
      });

      test('应该处理注销任务类型', () {
        final registry = TaskRegistry();

        registry.registerTaskType(
          'TempTask',
          (data) => TestTask(value: 1),
          (result) => result as int,
        );

        expect(registry.isRegistered('TempTask'), true);

        registry.unregister('TempTask');

        expect(registry.isRegistered('TempTask'), false);
      });

      test('应该处理清空注册表', () {
        final registry = TaskRegistry();

        registry.registerTaskType(
          'Task1',
          (data) => TestTask(value: 1),
          (result) => result as int,
        );
        registry.registerTaskType(
          'Task2',
          (data) => TestTask(value: 2),
          (result) => result as int,
        );

        expect(registry.taskTypes.length, 2);

        registry.clear();

        expect(registry.taskTypes, isEmpty);
      });
    });

    group('Worker配置边界测试', () {
      test('应该支持单Worker配置', () async {
        await engine.shutdown();

        await engine.initialize(maxWorkers: 1, taskRegistry: taskRegistry);

        final results = await Future.wait([
          engine.executeCPU(RecursiveTask(n: 10)),
          engine.executeCPU(RecursiveTask(n: 10)),
          engine.executeCPU(RecursiveTask(n: 10)),
        ]);

        expect(results, [55, 55, 55]);
      });

      test('应该将Worker限制在有效范围内', () async {
        await engine.shutdown();

        // 测试最小值限制
        await engine.initialize(maxWorkers: 0, taskRegistry: taskRegistry);
        expect(engine.isInitialized, true);
        await engine.shutdown();

        // 测试最大值限制
        await engine.initialize(maxWorkers: 100, taskRegistry: taskRegistry);
        expect(engine.isInitialized, true);
      });
    });

    group('统计信息测试', () {
      test('应该跟踪任务统计信息', () async {
        final task = TestTask(value: 1);
        await engine.executeCPU(task);

        final stats = engine.stats;
        expect(stats, isNotEmpty);
      });

      test('多个任务后应该返回一致的统计信息', () async {
        for (var i = 0; i < 10; i++) {
          await engine.executeCPU(TestTask(value: i));
        }

        final stats = engine.stats;
        expect(stats, isA<Map<String, dynamic>>());
      });
    });
  });
}
