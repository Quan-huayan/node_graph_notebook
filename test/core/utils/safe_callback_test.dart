import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/utils/safe_callback.dart';

void main() {
  group('SafeCallback', () {
    group('call()', () {
      test('应该成功执行有效回调', () {
        String callback() => 'result';

        final result = SafeCallback.call<String>(callback: callback);

        expect(result, equals('result'));
      });

      test('应该在回调为 null 时返回 null', () {
        final result = SafeCallback.call<String>(callback: null);

        expect(result, isNull);
      });

      test('应该在回调为 null 时返回默认值', () {
        final result = SafeCallback.call(
          callback: null,
          fallbackValue: 'default',
        );

        expect(result, equals('default'));
      });

      test('应该捕获回调异常并返回默认值', () {
        String throwingCallback() {
          throw Exception('Test exception');
        }

        final result = SafeCallback.call<String>(
          callback: throwingCallback,
          fallbackValue: 'fallback',
        );

        expect(result, equals('fallback'));
      });

      test('应该支持自定义错误处理', () {
        var errorHandled = false;

        String throwingCallback() {
          throw Exception('Test exception');
        }

        SafeCallback.call<String>(
          callback: throwingCallback,
          onError: (error) {
            errorHandled = true;
            expect(error, isA<Exception>());
          },
        );

        expect(errorHandled, true);
      });

      test('应该支持各种返回类型', () {
        String stringCallback() => 'string';
        int intCallback() => 42;
        bool boolCallback() => true;
        double doubleCallback() => 3.14;

        expect(SafeCallback.call<String>(callback: stringCallback), equals('string'));
        expect(SafeCallback.call<int>(callback: intCallback), equals(42));
        expect(SafeCallback.call<bool>(callback: boolCallback), isTrue);
        expect(SafeCallback.call<double>(callback: doubleCallback), equals(3.14));
      });

      test('应该支持 nullable 返回类型', () {
        String? callback() => null;

        final result = SafeCallback.call<String?>(callback: callback);

        expect(result, isNull);
      });

      test('应该支持 void 回调', () {
        var executed = false;

        void voidCallback() {
          executed = true;
        }

        SafeCallback.call(callback: voidCallback);

        expect(executed, true);
      });

      test('应该处理返回 dynamic 的回调', () {
        dynamic dynamicCallback() => 'dynamic result';

        final result = SafeCallback.call<String>(callback: dynamicCallback);

        expect(result, equals('dynamic result'));
      });
    });

    group('callAsync()', () {
      test('应该成功执行有效的异步回调', () async {
        Future<String> asyncCallback() async => 'async result';

        final result = await SafeCallback.callAsync<String>(callback: asyncCallback);

        expect(result, equals('async result'));
      });

      test('应该在回调为 null 时返回 null', () async {
        final result = await SafeCallback.callAsync<String>(callback: null);

        expect(result, isNull);
      });

      test('应该捕获异步回调异常', () async {
        Future<String> throwingCallback() async {
          throw Exception('Async exception');
        }

        final result = await SafeCallback.callAsync<String>(
          callback: throwingCallback,
        );

        expect(result, isNull);
      });

      test('应该支持异步错误处理', () async {
        var errorHandled = false;

        Future<String> throwingCallback() async {
          throw Exception('Async exception');
        }

        await SafeCallback.callAsync<String>(
          callback: throwingCallback,
          onError: (error) {
            errorHandled = true;
            expect(error, isA<Exception>());
          },
        );

        expect(errorHandled, true);
      });
    });

    group('callWithArg()', () {
      test('应该成功执行带参数的回调', () {
        String callback(String arg) => 'Hello, $arg';

        final result = SafeCallback.callWithArg<String, String>(
          callback: callback,
          arg: 'World',
        );

        expect(result, equals('Hello, World'));
      });

      test('应该在回调为 null 时返回默认值', () {
        final result = SafeCallback.callWithArg<String, String>(
          callback: null,
          arg: 'test',
          fallbackValue: 'default',
        );

        expect(result, equals('default'));
      });

      test('应该捕获带参数回调的异常', () {
        String throwingCallback(String arg) {
          throw Exception('Error with $arg');
        }

        final result = SafeCallback.callWithArg<String, String>(
          callback: throwingCallback,
          arg: 'test',
          fallbackValue: 'fallback',
        );

        expect(result, equals('fallback'));
      });

      test('应该支持各种参数类型', () {
        String intCallback(int arg) => 'Int: $arg';
        String boolCallback(bool arg) => 'Bool: $arg';
        String doubleCallback(double arg) => 'Double: $arg';

        expect(
          SafeCallback.callWithArg<String, int>(callback: intCallback, arg: 42),
          equals('Int: 42'),
        );
        expect(
          SafeCallback.callWithArg<String, bool>(callback: boolCallback, arg: true),
          equals('Bool: true'),
        );
        expect(
          SafeCallback.callWithArg<String, double>(callback: doubleCallback, arg: 3.14),
          equals('Double: 3.14'),
        );
      });
    });

    group('callWithArgs()', () {
      test('应该成功执行带多个参数的回调', () {
        String callback(List<dynamic> args) => 'Args: ${args.join(', ')}';

        final result = SafeCallback.callWithArgs<String>(
          callback: callback,
          args: ['a', 'b', 'c'],
        );

        expect(result, equals('Args: a, b, c'));
      });

      test('应该在回调为 null 时返回默认值', () {
        final result = SafeCallback.callWithArgs<String>(
          callback: null,
          args: [1, 2, 3],
          fallbackValue: 'default',
        );

        expect(result, equals('default'));
      });

      test('应该捕获多参数回调的异常', () {
        int callback(List<dynamic> args) {
          throw Exception('Error');
        }

        final result = SafeCallback.callWithArgs<int>(
          callback: callback,
          args: [1, 2],
          fallbackValue: 0,
        );

        expect(result, equals(0));
      });

      test('应该处理空参数列表', () {
        String callback(List<dynamic> args) => 'Count: ${args.length}';

        final result = SafeCallback.callWithArgs<String>(
          callback: callback,
          args: [],
        );

        expect(result, equals('Count: 0'));
      });
    });

    group('isCallable()', () {
      test('应该在回调存在时返回 true', () {
        String callback() => 'test';

        expect(SafeCallback.isCallable(callback), true);
      });

      test('应该在回调为 null 时返回 false', () {
        expect(SafeCallback.isCallable(null), false);
      });
    });

    group('Real-world Scenarios', () {
      test('应该处理可选的事件处理器', () {
        void Function()? eventHandler;

        // 未设置处理器
        SafeCallback.call(callback: eventHandler);

        // 设置处理器
        eventHandler = () {
          // 处理事件
        };

        expect(() => SafeCallback.call(callback: eventHandler), returnsNormally);
      });

      test('应该处理可能失败的回调', () {
        int riskyCallback() {
          final random = DateTime.now().millisecond % 2;
          if (random == 0) {
            return 100;
          } else {
            throw Exception('Random failure');
          }
        }

        final result = SafeCallback.call<int>(
          callback: riskyCallback,
          fallbackValue: 0,
        );

        expect(result, isIn([0, 100]));
      });

      test('应该支持链式调用', () {
        String callback1() => 'step1';
        String callback2() => 'step2';
        String callback3() => 'step3';

        final results = [
          SafeCallback.call<String>(callback: callback1, fallbackValue: ''),
          SafeCallback.call<String>(callback: callback2, fallbackValue: ''),
          SafeCallback.call<String>(callback: callback3, fallbackValue: ''),
        ];

        expect(results, equals(['step1', 'step2', 'step3']));
      });
    });

    group('Error Logging', () {
      test('应该记录回调执行失败的警告', () {
        var logged = false;

        // 注意：这个测试验证异常被正确捕获
        // 实际的日志记录需要通过其他方式验证
        String throwingCallback() {
          throw Exception('Test');
        }

        SafeCallback.call(
          callback: throwingCallback,
          onError: (error) {
            logged = true;
            expect(error, isA<Exception>());
          },
        );

        expect(logged, true);
      });
    });

    group('Type Safety', () {
      test('应该正确处理类型转换', () {
        int callback() => 42;

        final result = SafeCallback.call<int>(callback: callback);

        expect(result, equals(42));
        expect(result, isA<int>());
      });

      test('应该处理错误的类型转换', () {
        String callback() => 'string';

        // 尝试将 String 转换为 int 会失败
        final result = SafeCallback.call<int>(
          callback: callback,
          fallbackValue: 0,
        );

        // 由于类型转换失败，会返回 fallbackValue
        expect(result, equals(0));
      });

      test('应该支持 dynamic 类型', () {
        dynamic callback() => 'dynamic';

        final result = SafeCallback.call<dynamic>(callback: callback);

        expect(result, equals('dynamic'));
      });
    });
  });
}
