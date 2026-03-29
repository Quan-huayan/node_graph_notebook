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
    test('应该创建具有正确属性的 DataRecoveryResult', () {
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

    test('应该创建不带消息的 DataRecoveryResult', () {
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

  group('数据恢复服务', () {
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
      test('对于文件丢失错误应该返回正确的消息', () {
        const error = FileSystemException('Cannot find file', '/test/path');
        final message = service.getRecoveryMessage(error);

        expect(message, contains('数据文件丢失'));
      });

      test('对于权限错误应该返回正确的消息', () {
        const error = FileSystemException('Permission denied', '/test/path');
        final message = service.getRecoveryMessage(error);

        expect(message, contains('没有访问权限'));
      });

      test('对于未知错误应该返回通用消息', () {
        final error = Exception('Unknown error');
        final message = service.getRecoveryMessage(error);

        expect(message, contains('发生错误'));
      });
    });

    group('isRecoverableError', () {
      test('对于文件丢失错误应该返回 true', () {
        const error = FileSystemException('Cannot find file', '/test/path');
        expect(service.isRecoverableError(error), true);
      });

      test('对于目录错误应该返回 true', () {
        const error = FileSystemException('Directory not found', '/test/path');
        expect(service.isRecoverableError(error), true);
      });

      test('对于不可恢复的错误应该返回 false', () {
        final error = Exception('Unknown error');
        expect(service.isRecoverableError(error), false);
      });
    });
  });
}
