import '../../../../core/plugin/service_binding.dart';
import '../../../../core/repositories/repositories.dart';
import 'graph_service.dart';
import 'node_service.dart';

/// NodeService 绑定
///
/// 将 NodeService 注册到插件系统的依赖注入容器
class NodeServiceBinding extends ServiceBinding<NodeService> {
  @override
  NodeService createService(ServiceResolver resolver) {
    final nodeRepository = resolver.get<NodeRepository>();
    return NodeServiceImpl(nodeRepository);
  }
}

/// GraphService 绑定
///
/// 将 GraphService 注册到插件系统的依赖注入容器
/// GraphService 依赖 NodeRepository 和 GraphRepository
class GraphServiceBinding extends ServiceBinding<GraphService> {
  @override
  GraphService createService(ServiceResolver resolver) {
    final graphRepository = resolver.get<GraphRepository>();
    final nodeRepository = resolver.get<NodeRepository>();
    return GraphServiceImpl(graphRepository, nodeRepository);
  }
}