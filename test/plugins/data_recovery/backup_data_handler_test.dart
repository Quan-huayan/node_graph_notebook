import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/services/infrastructure/storage_path_service.dart';
import 'package:node_graph_notebook/plugins/data_recovery/command/backup_data_command.dart';
import 'package:node_graph_notebook/plugins/data_recovery/handler/backup_data_handler.dart';

@GenerateMocks([
  StoragePathService,
  CommandContext,
])
import 'backup_data_handler_test.mocks.dart';

void main() {
  group('BackupDataHandler', () {
    late BackupDataHandler handler;
    late MockStoragePathService mockStoragePathService;
    late MockCommandContext mockCommandContext;

    setUp(() {
      mockStoragePathService = MockStoragePathService();
      mockCommandContext = MockCommandContext();
      handler = BackupDataHandler(
        storagePathService: mockStoragePathService,
      );
    });

    test('should create backup successfully when directories exist', () async {
      final tempDir = Directory.systemTemp.createTempSync('backup_test_');
      final nodesDir = Directory('${tempDir.path}/nodes')..createSync();
      final graphsDir = Directory('${tempDir.path}/graphs')..createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => tempDir.path);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => nodesDir.path);
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => graphsDir.path);

      final command = BackupDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.backupPath, isNotNull);
      expect(result.data!.backupPath, contains('backup_'));

      final backupDir = Directory(result.data!.backupPath!);
      expect(backupDir.existsSync(), true);
      expect(Directory('${backupDir.path}/nodes').existsSync(), true);
      expect(Directory('${backupDir.path}/graphs').existsSync(), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should create backup when nodes directory does not exist', () async {
      final tempDir = Directory.systemTemp.createTempSync('backup_test_');
      final graphsDir = Directory('${tempDir.path}/graphs')..createSync();
      final nodesDir = Directory('${tempDir.path}/nodes');

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => tempDir.path);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => nodesDir.path);
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => graphsDir.path);

      final command = BackupDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);

      final backupDir = Directory(result.data!.backupPath!);
      expect(backupDir.existsSync(), true);
      expect(Directory('${backupDir.path}/graphs').existsSync(), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should create backup when graphs directory does not exist', () async {
      final tempDir = Directory.systemTemp.createTempSync('backup_test_');
      final nodesDir = Directory('${tempDir.path}/nodes')..createSync();
      final graphsDir = Directory('${tempDir.path}/graphs');

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => tempDir.path);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => nodesDir.path);
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => graphsDir.path);

      final command = BackupDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);

      final backupDir = Directory(result.data!.backupPath!);
      expect(backupDir.existsSync(), true);
      expect(Directory('${backupDir.path}/nodes').existsSync(), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should create backup when both directories do not exist', () async {
      final tempDir = Directory.systemTemp.createTempSync('backup_test_');
      final nodesDir = Directory('${tempDir.path}/nodes');
      final graphsDir = Directory('${tempDir.path}/graphs');

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => tempDir.path);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => nodesDir.path);
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => graphsDir.path);

      final command = BackupDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);

      final backupDir = Directory(result.data!.backupPath!);
      expect(backupDir.existsSync(), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should copy files from nodes directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('backup_test_');
      final nodesDir = Directory('${tempDir.path}/nodes')..createSync();
      final graphsDir = Directory('${tempDir.path}/graphs')..createSync();

      final testFile = File('${nodesDir.path}/test_node.json');
      await testFile.writeAsString('{"id": "test"}');

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => tempDir.path);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => nodesDir.path);
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => graphsDir.path);

      final command = BackupDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);

      final backupNodesDir = Directory('${result.data!.backupPath}/nodes');
      final backupFile = File('${backupNodesDir.path}/test_node.json');
      expect(backupFile.existsSync(), true);
      expect(await backupFile.readAsString(), '{"id": "test"}');

      tempDir.deleteSync(recursive: true);
    });

    test('should copy nested directories', () async {
      final tempDir = Directory.systemTemp.createTempSync('backup_test_');
      final nodesDir = Directory('${tempDir.path}/nodes')..createSync();
      final graphsDir = Directory('${tempDir.path}/graphs')..createSync();

      final subDir = Directory('${nodesDir.path}/subdir')..createSync();
      final testFile = File('${subDir.path}/test.json');
      await testFile.writeAsString('{"test": true}');

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => tempDir.path);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => nodesDir.path);
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => graphsDir.path);

      final command = BackupDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);

      final backupSubDir = Directory('${result.data!.backupPath}/nodes/subdir');
      final backupFile = File('${backupSubDir.path}/test.json');
      expect(backupFile.existsSync(), true);
      expect(await backupFile.readAsString(), '{"test": true}');

      tempDir.deleteSync(recursive: true);
    });

    test('should return failure when storage path fails', () async {
      when(mockStoragePathService.getStoragePath()).thenThrow(Exception('Storage path error'));

      final command = BackupDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('备份失败'));
    });

    test('should return failure when backup directory creation fails', () async {
      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => '/invalid/path/that/does/not/exist');

      final command = BackupDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('备份失败'));
    });

    test('should include success message in result', () async {
      final tempDir = Directory.systemTemp.createTempSync('backup_test_');
      final nodesDir = Directory('${tempDir.path}/nodes')..createSync();
      final graphsDir = Directory('${tempDir.path}/graphs')..createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => tempDir.path);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => nodesDir.path);
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => graphsDir.path);

      final command = BackupDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.message, contains('备份成功创建于'));
      expect(result.data!.message, contains(result.data!.backupPath));

      tempDir.deleteSync(recursive: true);
    });
  });
}