import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/graph_bloc.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/graph_event.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/graph_state.dart';

// 用于集成测试的 Mock 实现
class MockGraphRepository implements GraphRepository {
  Graph? _currentGraph;

  @override
  Future<Graph?> getCurrent() async => _currentGraph;

  @override
  Future<Graph?> load(String id) async => _currentGraph;

  @override
  Future<void> save(Graph graph) async {
    _currentGraph = graph;
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Graph>> getAll() async => [];

  @override
  Future<void> export(String graphId, String filePath) async {}

  @override
  Future<Graph> import(String filePath) async {
    throw UnimplementedError();
  }

  @override
  Future<void> setCurrent(String graphId) async {}
}

class MockNodeRepository implements NodeRepository {
  @override
  Future<Node?> load(String id) async => null;

  @override
  Future<List<Node>> loadAll(List<String> ids) async => [];

  @override
  Future<void> save(Node node) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Node>> queryAll() async => [];

  @override
  Future<List<Node>> search({String? query, List<String>? tags, String? content, DateTime? startDate, DateTime? endDate, String? title}) async => [];

  @override
  Future<void> saveAll(List<Node> nodes) async {}

  @override
  String getNodeFilePath(String nodeId) => '';

  @override
  Future<MetadataIndex> getMetadataIndex() async => MetadataIndex(nodes: [], lastUpdated: DateTime.now());

  @override
  Future<void> updateIndex(Node node) async {}
}

void main() {
  group('图集成测试', () {
    late CommandBus commandBus;
    late GraphRepository graphRepository;
    late NodeRepository nodeRepository;
    late GraphBloc graphBloc;

    setUp(() {
      commandBus = CommandBus();
      graphRepository = MockGraphRepository();
      nodeRepository = MockNodeRepository();

      graphBloc = GraphBloc(
        commandBus: commandBus,
        graphRepository: graphRepository,
        nodeRepository: nodeRepository,
      );
    });

    tearDown(() {
      graphBloc.close();
      commandBus.dispose();
    });

    test('应该能够创建并初始化图', () async {
      // 测试创建图
      graphBloc.add(const GraphCreateEvent('测试图'));
      await Future.delayed(const Duration(milliseconds: 100));

      // 测试初始化图
      graphBloc.add(const GraphInitializeEvent());
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证状态
      expect(graphBloc.state.graph, isNotNull);
      expect(graphBloc.state.loadingState, LoadingState.loaded);
    });

    test('应该能够添加并选择节点', () async {
      // 初始化图
      graphBloc.add(const GraphCreateEvent('测试图'));
      await Future.delayed(const Duration(milliseconds: 100));

      // 添加节点
      graphBloc.add(const NodeAddEvent('test_node', position: Offset(100, 200)));
      await Future.delayed(const Duration(milliseconds: 100));

      // 选择节点
      graphBloc.add(const NodeSelectEvent('test_node', addToSelection: false));
      await Future.delayed(const Duration(milliseconds: 50));

      // 验证状态
      expect(graphBloc.state.selectionState.selectedNodeIds, contains('test_node'));
    });

    test('应该能够处理视图状态变化', () async {
      // 切换连接显示
      graphBloc.add(const ViewToggleConnectionsEvent());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(graphBloc.state.viewState.showConnections, false);

      // 切换网格显示
      graphBloc.add(const ViewToggleGridEvent());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(graphBloc.state.viewState.gridVisible, false);

      // 再次切换连接显示
      graphBloc.add(const ViewToggleConnectionsEvent());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(graphBloc.state.viewState.showConnections, true);
    });

    test('应该能够清除选择', () async {
      // 选择节点
      graphBloc.add(const NodeSelectEvent('test_node', addToSelection: false));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(graphBloc.state.selectionState.selectedNodeIds, contains('test_node'));

      // 清除选择
      graphBloc.add(const SelectionClearEvent());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(graphBloc.state.selectionState.selectedNodeIds, isEmpty);
    });
  });
}
