import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/cqrs/commands/command_bus.dart';
import 'package:node_graph_notebook/core/graph/adjacency_list.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/graph/command/node_commands.dart';
import 'package:node_graph_notebook/plugins/graph/handler/connect_nodes_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/create_node_handler.dart';
import 'package:node_graph_notebook/plugins/graph/service/node_service.dart';
import 'package:path/path.dart' as path;

/// 图工作流集成测试
///
/// 测试完整的节点创建、连接、查询、删除工作流
void main() {
  group('图工作流集成测试', () {
    late String testDir;
    late FileSystemNodeRepository repository;
    late NodeService nodeService;
    late CommandBus commandBus;

    setUp(() async {
      testDir = Directory.systemTemp.createTempSync('graph_integration_').path;

      // 初始化存储库
      repository = FileSystemNodeRepository(nodesDir: path.join(testDir, 'nodes'));
      await repository.init();

      // 初始化服务
      nodeService = NodeServiceImpl(repository);

      // 初始化命令总线
      commandBus = CommandBus();

      // 注册命令处理器
      commandBus.registerHandler(CreateNodeHandler(nodeService), CreateNodeCommand);
      commandBus.registerHandler(ConnectNodesHandler(repository), ConnectNodesCommand);
    });

    tearDown(() async {
      commandBus.dispose();

      // 延迟一下确保文件句柄释放
      await Future.delayed(const Duration(milliseconds: 100));

      final dir = Directory(testDir);
      if (dir.existsSync()) {
        try {
          await dir.delete(recursive: true);
        } catch (e) {
          // 忽略删除错误
        }
      }
    });

    group('完整节点生命周期工作流', () {
      test('应该能够创建、连接、更新和删除节点', () async {
        // 1. 创建节点
        final createResult1 = await commandBus.dispatch(CreateNodeCommand(
          title: '节点 A',
          content: '节点 A 的内容',
        ));
        expect(createResult1.isSuccess, true);
        final nodeA = createResult1.data!;

        final createResult2 = await commandBus.dispatch(CreateNodeCommand(
          title: '节点 B',
          content: '节点 B 的内容',
        ));
        expect(createResult2.isSuccess, true);
        final nodeB = createResult2.data!;

        final createResult3 = await commandBus.dispatch(CreateNodeCommand(
          title: '节点 C',
          content: '节点 C 的内容',
        ));
        expect(createResult3.isSuccess, true);
        final nodeC = createResult3.data!;

        // 2. 连接节点
        final connectResult1 = await commandBus.dispatch(ConnectNodesCommand(
          sourceId: nodeA.id,
          targetId: nodeB.id,
        ));
        expect(connectResult1.isSuccess, true);

        final connectResult2 = await commandBus.dispatch(ConnectNodesCommand(
          sourceId: nodeB.id,
          targetId: nodeC.id,
        ));
        expect(connectResult2.isSuccess, true);

        final connectResult3 = await commandBus.dispatch(ConnectNodesCommand(
          sourceId: nodeC.id,
          targetId: nodeA.id,
        ));
        expect(connectResult3.isSuccess, true);

        // 3. 验证连接 - 从存储库重新加载节点
        final loadedA = await repository.load(nodeA.id);
        expect(loadedA!.references.containsKey(nodeB.id), true);

        final loadedB = await repository.load(nodeB.id);
        expect(loadedB!.references.containsKey(nodeC.id), true);

        final loadedC = await repository.load(nodeC.id);
        expect(loadedC!.references.containsKey(nodeA.id), true);

        // 4. 验证邻接表 - 需要重新构建
        final allNodes = await repository.queryAll();
        final adjacencyList = AdjacencyList(storageDir: testDir);
        await adjacencyList.init();
        adjacencyList.buildFromNodes(allNodes);

        expect(adjacencyList.hasEdge(nodeA.id, nodeB.id), true);
        expect(adjacencyList.hasEdge(nodeB.id, nodeC.id), true);
        expect(adjacencyList.hasEdge(nodeC.id, nodeA.id), true);

        // 5. 搜索节点
        final searchResults = await repository.search(title: '节点');
        expect(searchResults.length, 3);

        // 6. 删除节点
        await repository.delete(nodeB.id);

        // 7. 验证删除
        final deletedB = await repository.load(nodeB.id);
        expect(deletedB, isNull);
      });

      test('应该能够处理具有多个连接的复杂图', () async {
        // 创建一个星型图结构
        final centerResult = await commandBus.dispatch(CreateNodeCommand(
          title: '中心节点',
          content: '中心枢纽',
        ));
        final centerNode = centerResult.data!;

        final leafNodes = <Node>[];
        for (var i = 0; i < 5; i++) {
          final result = await commandBus.dispatch(CreateNodeCommand(
            title: '叶子节点 $i',
            content: '叶子内容 $i',
          ));
          leafNodes.add(result.data!);

          // 连接到中心节点
          await commandBus.dispatch(ConnectNodesCommand(
            sourceId: leafNodes[i].id,
            targetId: centerNode.id,
          ));
        }

        // 验证所有连接 - 从存储库重新加载
        for (final leaf in leafNodes) {
          final loadedLeaf = await repository.load(leaf.id);
          expect(loadedLeaf!.references.containsKey(centerNode.id), true);
        }

        // 验证搜索
        final leafResults = await repository.search(title: '叶子');
        expect(leafResults.length, 5);
      });

      test('应该能够在保留连接的情况下处理节点更新', () async {
        // 创建节点并连接
        final result1 = await commandBus.dispatch(CreateNodeCommand(
          title: '原始标题',
          content: '原始内容',
        ));
        final node = result1.data!;

        final result2 = await commandBus.dispatch(CreateNodeCommand(
          title: '已连接节点',
          content: '已连接内容',
        ));
        final connectedNode = result2.data!;

        await commandBus.dispatch(ConnectNodesCommand(
          sourceId: node.id,
          targetId: connectedNode.id,
        ));

        // 重新加载节点以获取最新的连接信息
        final nodeWithConnection = await repository.load(node.id);
        expect(nodeWithConnection, isNotNull);

        // 更新节点（保留连接信息）
        final updatedNode = nodeWithConnection!.copyWith(
          title: '更新后的标题',
          content: '更新后的内容',
        );
        await repository.save(updatedNode);

        // 验证更新
        final loaded = await repository.load(node.id);
        expect(loaded!.title, '更新后的标题');
        expect(loaded.content, '更新后的内容');

        // 验证连接仍然保留
        expect(loaded.references.containsKey(connectedNode.id), true);
      });
    });

    group('错误恢复工作流', () {
      test('应该能够优雅地处理连接到不存在节点的情况', () async {
        // 创建源节点
        final result = await commandBus.dispatch(CreateNodeCommand(
          title: '源节点',
          content: '源内容',
        ));
        final sourceNode = result.data!;

        // 尝试连接到不存在的节点
        final connectResult = await commandBus.dispatch(ConnectNodesCommand(
          sourceId: sourceNode.id,
          targetId: 'non-existent-id',
        ));

        expect(connectResult.isSuccess, false);
        expect(connectResult.error, contains('目标节点不存在'));
      });

      test('应该能够处理重复的连接尝试', () async {
        // 创建两个节点
        final result1 = await commandBus.dispatch(CreateNodeCommand(
          title: '节点 1',
          content: '内容 1',
        ));
        final node1 = result1.data!;

        final result2 = await commandBus.dispatch(CreateNodeCommand(
          title: '节点 2',
          content: '内容 2',
        ));
        final node2 = result2.data!;

        // 第一次连接
        final connectResult1 = await commandBus.dispatch(ConnectNodesCommand(
          sourceId: node1.id,
          targetId: node2.id,
        ));
        expect(connectResult1.isSuccess, true);

        // 第二次连接（重复）
        final connectResult2 = await commandBus.dispatch(ConnectNodesCommand(
          sourceId: node1.id,
          targetId: node2.id,
        ));
        expect(connectResult2.isSuccess, false);
        expect(connectResult2.error, contains('节点连接已存在'));
      });

      test('应该能够从损坏的节点文件中恢复', () async {
        // 创建节点
        final result = await commandBus.dispatch(CreateNodeCommand(
          title: '测试节点',
          content: '测试内容',
        ));
        final node = result.data!;

        // 损坏文件
        final file = File(repository.getNodeFilePath(node.id));
        await file.writeAsString('corrupted content {{{');

        // 查询所有节点应该跳过损坏的文件或抛出异常
        try {
          final allNodes = await repository.queryAll();
          // 如果成功返回，损坏的文件应该被跳过
          final corruptedNode = allNodes.where((n) => n.id == node.id);
          expect(corruptedNode.isEmpty, true);
        } catch (e) {
          // 如果抛出异常也是可接受的行为
          expect(e, isA<Exception>());
        }
      });
    });

    group('批量操作工作流', () {
      test('应该能够处理批量节点创建', () async {
        const batchSize = 50;
        final nodes = <Node>[];

        for (var i = 0; i < batchSize; i++) {
          final result = await commandBus.dispatch(CreateNodeCommand(
            title: '批量节点 $i',
            content: '批量内容 $i',
          ));
          nodes.add(result.data!);
        }

        // 验证所有节点都已创建
        final allNodes = await repository.queryAll();
        expect(allNodes.length, batchSize);

        // 验证索引
        final index = await repository.getMetadataIndex();
        expect(index.nodes.length, batchSize);
      });

      test('应该能够处理批量连接', () async {
        // 创建节点链
        const chainLength = 10;
        final nodes = <Node>[];

        for (var i = 0; i < chainLength; i++) {
          final result = await commandBus.dispatch(CreateNodeCommand(
            title: '链式节点 $i',
            content: '链式内容 $i',
          ));
          nodes.add(result.data!);
        }

        // 连接成链
        for (var i = 0; i < chainLength - 1; i++) {
          final result = await commandBus.dispatch(ConnectNodesCommand(
            sourceId: nodes[i].id,
            targetId: nodes[i + 1].id,
          ));
          expect(result.isSuccess, true);
        }

        // 验证链 - 从存储库重新加载
        for (var i = 0; i < chainLength - 1; i++) {
          final loadedNode = await repository.load(nodes[i].id);
          expect(loadedNode!.references.containsKey(nodes[i + 1].id), true);
        }
      });

      test('应该能够处理批量删除', () async {
        // 创建节点
        const nodeCount = 20;
        final nodeIds = <String>[];

        for (var i = 0; i < nodeCount; i++) {
          final result = await commandBus.dispatch(CreateNodeCommand(
            title: '节点 $i',
            content: '内容 $i',
          ));
          nodeIds.add(result.data!.id);
        }

        // 批量删除
        for (final id in nodeIds) {
          await repository.delete(id);
        }

        // 验证所有节点已删除
        final allNodes = await repository.queryAll();
        expect(allNodes, isEmpty);
      });
    });

    group('搜索和过滤工作流', () {
      test('应该能够按多个条件搜索', () async {
        // 创建测试数据
        await commandBus.dispatch(CreateNodeCommand(
          title: 'Python 编程',
          content: '学习 Python 基础',
        ));
        await commandBus.dispatch(CreateNodeCommand(
          title: 'Dart 语言',
          content: '用于 Flutter 开发的 Dart',
        ));
        await commandBus.dispatch(CreateNodeCommand(
          title: '机器学习',
          content: 'Python 机器学习教程',
        ));

        // 按标题搜索
        final titleResults = await repository.search(title: 'Python');
        expect(titleResults.length, 1);

        // 按内容搜索
        final contentResults = await repository.search(content: 'Python');
        expect(contentResults.length, 2);

        // 组合搜索
        final combinedResults = await repository.search(
          title: 'Python',
          content: 'Python',
        );
        expect(combinedResults.length, 2);
      });

      test('应该能够处理日期范围过滤', () async {
        // 创建带特定日期的节点
        final node1 = Node(
          id: 'node_1',
          title: '旧节点',
          content: '很久以前创建的',
          references: const {},
          position: const Offset(0, 0),
          size: const Size(100, 100),
          viewMode: NodeViewMode.titleOnly,
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime.now(),
          metadata: const {},
        );
        await repository.save(node1);

        final node2 = Node(
          id: 'node_2',
          title: '最近节点',
          content: '最近创建的',
          references: const {},
          position: const Offset(0, 0),
          size: const Size(100, 100),
          viewMode: NodeViewMode.titleOnly,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );
        await repository.save(node2);

        // 按日期范围搜索
        final recentResults = await repository.search(
          startDate: DateTime(2024, 1, 1),
        );
        expect(recentResults.length, 1);
        expect(recentResults[0].title, '最近节点');
      });
    });

    group('持久化和恢复工作流', () {
      test('应该能够持久化和恢复图状态', () async {
        // 创建图结构
        final result1 = await commandBus.dispatch(CreateNodeCommand(
          title: '根节点',
          content: '根内容',
        ));
        final rootNode = result1.data!;

        for (var i = 0; i < 3; i++) {
          final result = await commandBus.dispatch(CreateNodeCommand(
            title: '子节点 $i',
            content: '子内容 $i',
          ));
          await commandBus.dispatch(ConnectNodesCommand(
            sourceId: rootNode.id,
            targetId: result.data!.id,
          ));
        }

        // 创建新的存储库实例（模拟应用重启）
        final newRepository = FileSystemNodeRepository(
          nodesDir: path.join(testDir, 'nodes'),
        );
        await newRepository.init();

        // 验证数据恢复
        final restoredRoot = await newRepository.load(rootNode.id);
        expect(restoredRoot, isNotNull);
        expect(restoredRoot!.references.length, 3);
      });
    });
  });
}
