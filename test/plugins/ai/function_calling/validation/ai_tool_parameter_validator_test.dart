import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/ai/function_calling/validation/ai_tool_parameter_validator.dart';

void main() {
  group('AIToolParameterValidator', () {
    late AIToolParameterValidator validator;

    setUp(() {
      validator = const AIToolParameterValidator(
        strictMode: false,
        enableSecurityChecks: true,
      );
    });

    group('Security: Prototype Pollution Prevention', () {
      test('应该拒绝 __proto__ 键', () {
        final arguments = <String, dynamic>{
          '__proto__': {'polluted': true},
        };

        final schema = <String, dynamic>{
          'properties': {},
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('__proto__'))),
        );
      });

      test('应该拒绝 constructor 键', () {
        final arguments = <String, dynamic>{
          'constructor': {'prototype': {'polluted': true}},
        };

        final schema = <String, dynamic>{
          'properties': {},
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('constructor'))),
        );
      });

      test('应该拒绝 prototype 键', () {
        final arguments = <String, dynamic>{
          'prototype': {'polluted': true},
        };

        final schema = <String, dynamic>{
          'properties': {},
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('prototype'))),
        );
      });

      test('应该检测嵌套对象中的原型污染', () {
        final arguments = <String, dynamic>{
          'nested': {
            'deep': {
              '__proto__': {'polluted': true},
            },
          },
        };

        final schema = <String, dynamic>{
          'properties': {
            'nested': {'type': 'object'},
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('__proto__'))),
        );
      });
    });

    group('Security: DoS Prevention', () {
      test('应该拒绝超大字符串', () {
        final arguments = <String, dynamic>{
          'text': 'a' * 200000, // 超过默认 maxStringLength (100000)
        };

        final schema = <String, dynamic>{
          'properties': {
            'text': {'type': 'string'},
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('exceeds maximum'))),
        );
      });

      test('应该拒绝深度嵌套对象', () {
        // 创建深度为 15 的嵌套对象（超过默认 maxNestingDepth 10）
        var nested = <String, dynamic>{'value': 1};
        for (var i = 0; i < 15; i++) {
          nested = {'nested': nested};
        }

        final arguments = <String, dynamic>{
          'deep': nested,
        };

        final schema = <String, dynamic>{
          'properties': {
            'deep': {'type': 'object'},
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('nesting depth'))),
        );
      });

      test('应该拒绝数组中的超大字符串', () {
        final arguments = <String, dynamic>{
          'items': ['a' * 200000],
        };

        final schema = <String, dynamic>{
          'properties': {
            'items': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('exceeds maximum'))),
        );
      });
    });

    group('Schema Validation', () {
      test('应该接受有效的字符串参数', () {
        final arguments = <String, dynamic>{
          'title': 'Test Node',
        };

        final schema = <String, dynamic>{
          'properties': {
            'title': {'type': 'string'},
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          returnsNormally,
        );
      });

      test('应该拒绝错误的参数类型', () {
        final arguments = <String, dynamic>{
          'count': 'not a number',
        };

        final schema = <String, dynamic>{
          'properties': {
            'count': {'type': 'integer'},
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('must be integer'))),
        );
      });

      test('应该拒绝缺失的必需参数', () {
        final arguments = <String, dynamic>{
          'optional': 'value',
        };

        final schema = <String, dynamic>{
          'properties': {
            'required_param': {'type': 'string'},
            'optional': {'type': 'string'},
          },
          'required': ['required_param'],
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('Missing required parameter'))),
        );
      });

      test('应该验证数字范围', () {
        final arguments = <String, dynamic>{
          'priority': 15, // 超过 maximum 10
        };

        final schema = <String, dynamic>{
          'properties': {
            'priority': {
              'type': 'integer',
              'minimum': 0,
              'maximum': 10,
            },
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('must be <= 10'))),
        );
      });

      test('应该验证数组类型', () {
        final arguments = <String, dynamic>{
          'tags': 'not an array',
        };

        final schema = <String, dynamic>{
          'properties': {
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('must be array'))),
        );
      });

      test('应该验证数组元素类型', () {
        final arguments = <String, dynamic>{
          'tags': ['valid', 123, 'invalid'],
        };

        final schema = <String, dynamic>{
          'properties': {
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()),
        );
      });

      test('应该验证嵌套对象', () {
        final arguments = <String, dynamic>{
          'metadata': {
            'invalid': 123, // 应该是 string
          },
        };

        final schema = <String, dynamic>{
          'properties': {
            'metadata': {
              'type': 'object',
              'properties': {
                'invalid': {'type': 'string'},
              },
            },
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()),
        );
      });

      test('应该接受布尔值参数', () {
        final arguments = <String, dynamic>{
          'isFolder': true,
        };

        final schema = <String, dynamic>{
          'properties': {
            'isFolder': {'type': 'boolean'},
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          returnsNormally,
        );
      });

      test('应该拒绝错误的布尔值类型', () {
        final arguments = <String, dynamic>{
          'isFolder': 'true',
        };

        final schema = <String, dynamic>{
          'properties': {
            'isFolder': {'type': 'boolean'},
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('must be boolean'))),
        );
      });
    });

    group('Strict Mode', () {
      test('严格模式下应该拒绝未知参数', () {
        const validator = AIToolParameterValidator(
          strictMode: true,
          enableSecurityChecks: true,
        );

        final arguments = <String, dynamic>{
          'known': 'value',
          'unknown': 'value',
        };

        final schema = <String, dynamic>{
          'properties': {
            'known': {'type': 'string'},
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()
              .having((e) => e.message, 'message', contains('Unknown parameter'))),
        );
      });

      test('非严格模式下应该接受未知参数', () {
        final arguments = <String, dynamic>{
          'known': 'value',
          'unknown': 'value',
        };

        final schema = <String, dynamic>{
          'properties': {
            'known': {'type': 'string'},
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          returnsNormally,
        );
      });
    });

    group('Security Checks Disabled', () {
      test('禁用安全检查时应该允许原型污染键', () {
        const validator = AIToolParameterValidator(
          enableSecurityChecks: false,
        );

        final arguments = <String, dynamic>{
          '__proto__': {'polluted': true},
        };

        final schema = <String, dynamic>{
          'properties': {},
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          returnsNormally,
        );
      });
    });

    group('Complex Real-world Scenarios', () {
      test('应该验证复杂的嵌套 schema', () {
        final arguments = <String, dynamic>{
          'node': {
            'title': 'Test Node',
            'content': 'Node content',
            'metadata': {
              'tags': ['tag1', 'tag2'],
              'priority': 5,
            },
          },
          'connectTo': ['node1', 'node2'],
        };

        final schema = <String, dynamic>{
          'properties': {
            'node': {
              'type': 'object',
              'properties': {
                'title': {'type': 'string'},
                'content': {'type': 'string'},
                'metadata': {
                  'type': 'object',
                  'properties': {
                    'tags': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                    'priority': {
                      'type': 'integer',
                      'minimum': 0,
                      'maximum': 10,
                    },
                  },
                },
              },
              'required': ['title'],
            },
            'connectTo': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
          'required': ['node'],
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          returnsNormally,
        );
      });

      test('应该在复杂嵌套中检测到类型错误', () {
        final arguments = <String, dynamic>{
          'node': {
            'title': 'Test Node',
            'metadata': {
              'tags': ['valid', 123], // 错误：数字不能在字符串数组中
            },
          },
        };

        final schema = <String, dynamic>{
          'properties': {
            'node': {
              'type': 'object',
              'properties': {
                'title': {'type': 'string'},
                'metadata': {
                  'type': 'object',
                  'properties': {
                    'tags': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                  },
                },
              },
            },
          },
        };

        expect(
          () => validator.validateParameters('test_tool', arguments, schema),
          throwsA(isA<AIToolParameterValidationException>()),
        );
      });
    });
  });
}
