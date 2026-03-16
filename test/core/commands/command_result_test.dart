import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';

void main() {
  group('CommandResult', () {
    test('should create a success result with data', () {
      final result = CommandResult.success('test data');
      expect(result.isSuccess, true);
      expect(result.data, 'test data');
      expect(result.error, null);
    });

    test('should create a success result without data', () {
      final result = CommandResult.success();
      expect(result.isSuccess, true);
      expect(result.data, null);
      expect(result.error, null);
    });

    test('should create a failure result', () {
      const errorMessage = 'Test error';
      final result = CommandResult.failure(errorMessage);
      expect(result.isSuccess, false);
      expect(result.data, null);
      expect(result.error, errorMessage);
    });

    test('should create a typed failure result', () {
      const errorMessage = 'Test error';
      final result = CommandResult.failureTyped<String>(errorMessage);
      expect(result.isSuccess, false);
      expect(result.data, null);
      expect(result.error, errorMessage);
    });

    test('should return data or throw for success result', () {
      final result = CommandResult.success('test data');
      expect(() => result.dataOrThrow, returnsNormally);
      expect(result.dataOrThrow, 'test data');
    });

    test('should throw exception for failure result', () {
      const errorMessage = 'Test error';
      final result = CommandResult.failure(errorMessage);
      expect(() => result.dataOrThrow, throwsA(isA<CommandExecutionException>()));
    });

    test('should map success result data', () {
      final result = CommandResult.success(10);
      final mappedResult = result.map((data) => data.toString());
      expect(mappedResult.isSuccess, true);
      expect(mappedResult.data, '10');
    });

    test('should map failure result to same error', () {
      const errorMessage = 'Test error';
      final result = CommandResult.failure(errorMessage);
      final mappedResult = result.map((data) => data.toString());
      expect(mappedResult.isSuccess, false);
      expect(mappedResult.error, errorMessage);
    });

    test('should handle mapping error', () {
      final result = CommandResult.success('not a number');
      final mappedResult = result.map(int.parse);
      expect(mappedResult.isSuccess, false);
      expect(mappedResult.error, isNotNull);
    });
  });

  group('CommandExecutionException', () {
    test('should create exception with message', () {
      const errorMessage = 'Test error';
      final exception = CommandExecutionException(errorMessage);
      expect(exception.message, errorMessage);
      expect(exception.toString(), 'CommandExecutionException: $errorMessage');
    });
  });
}
