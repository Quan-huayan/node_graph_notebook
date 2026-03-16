import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/graph_bloc.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/graph_event.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/graph_state.dart';

// Mock implementations for integration testing
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
  group('Graph Integration Tests', () {
    late CommandBus commandBus;
    late GraphRepository graphRepository;
    late NodeRepository nodeRepository;
    late AppEventBus eventBus;
    late GraphBloc graphBloc;

    setUp(() {
      commandBus = CommandBus();
      graphRepository = MockGraphRepository();
      nodeRepository = MockNodeRepository();
      eventBus = AppEventBus();

      graphBloc = GraphBloc(
        commandBus: commandBus,
        graphRepository: graphRepository,
        nodeRepository: nodeRepository,
        eventBus: eventBus,
      );
    });

    tearDown(() {
      graphBloc.close();
      commandBus.dispose();
      eventBus.dispose();
    });

    test('should create and initialize a graph', () async {
      // 测试创建图
      graphBloc.add(const GraphCreateEvent('Test Graph'));
      await Future.delayed(const Duration(milliseconds: 100));

      // 测试初始化图
      graphBloc.add(const GraphInitializeEvent());
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证状态
      expect(graphBloc.state.graph, isNotNull);
      expect(graphBloc.state.loadingState, LoadingState.loaded);
    });

    test('should add and select a node', () async {
      // 初始化图
      graphBloc.add(const GraphCreateEvent('Test Graph'));
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

    test('should handle view state changes', () async {
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

    test('should clear selection', () async {
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