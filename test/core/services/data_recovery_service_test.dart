import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:node_graph_notebook/core/repositories/repositories.dart';
import 'package:node_graph_notebook/core/services/services.dart';

import 'data_recovery_service_test.mocks.dart';

@GenerateMocks([
  NodeRepository,
  GraphRepository,
  SettingsService,
])
void main() {
  group('DataRecoveryResult', () {
    test('should create DataRecoveryResult with correct properties', () {
      const result = DataRecoveryResult(
        success: true,
        repairedIssues: 5,
        issuesFound: 10,
        message: 'Test message',
      );

      expect(result.success, true);
      expect(result.repairedIssues, 5);
      expect(result.issuesFound, 10);
      expect(result.message, 'Test message');
    });

    test('should create DataRecoveryResult without message', () {
      const result = DataRecoveryResult(
        success: false,
        repairedIssues: 0,
        issuesFound: 1,
      );

      expect(result.success, false);
      expect(result.repairedIssues, 0);
      expect(result.issuesFound, 1);
      expect(result.message, null);
    });
  });

  group('DataRecoveryService', () {
    late DataRecoveryService service;
    late MockNodeRepository mockNodeRepository;
    late MockGraphRepository mockGraphRepository;
    late MockSettingsService mockSettingsService;

    setUp(() {
      mockNodeRepository = MockNodeRepository();
      mockGraphRepository = MockGraphRepository();
      mockSettingsService = MockSettingsService();

      service = DataRecoveryService(
        nodeRepository: mockNodeRepository,
        graphRepository: mockGraphRepository,
        settingsService: mockSettingsService,
      );
    });

    group('getRecoveryMessage', () {
      test('should return correct message for missing file error', () {
        const error = FileSystemException('Cannot find file', '/test/path');
        final message = service.getRecoveryMessage(error);

        expect(message, contains('数据文件丢失'));
      });

      test('should return correct message for permission error', () {
        const error = FileSystemException('Permission denied', '/test/path');
        final message = service.getRecoveryMessage(error);

        expect(message, contains('没有访问权限'));
      });

      test('should return generic message for unknown errors', () {
        final error = Exception('Unknown error');
        final message = service.getRecoveryMessage(error);

        expect(message, contains('发生错误'));
      });
    });

    group('isRecoverableError', () {
      test('should return true for missing file errors', () {
        const error = FileSystemException('Cannot find file', '/test/path');
        expect(service.isRecoverableError(error), true);
      });

      test('should return true for directory errors', () {
        const error = FileSystemException('Directory not found', '/test/path');
        expect(service.isRecoverableError(error), true);
      });

      test('should return false for non-recoverable errors', () {
        final error = Exception('Unknown error');
        expect(service.isRecoverableError(error), false);
      });
    });
  });
}
