import '../../../../core/plugin/service_binding.dart';
import '../../../../core/repositories/repositories.dart';
import '../../../../plugins/graph/service/graph_service.dart';
import '../../../../plugins/graph/service/node_service.dart';
import 'converter_service.dart';
import 'converter_service_impl.dart';
import 'import_export_service.dart';

/// ConverterService 绑定
///
/// 将 ConverterService 注册到插件系统的依赖注入容器
class ConverterServiceBinding extends ServiceBinding<ConverterService> {
  @override
  ConverterService createService(ServiceResolver resolver) {
    final nodeRepository = resolver.get<NodeRepository>();
    return ConverterServiceImpl(nodeRepository);
  }
}

/// ImportExportService 绑定
///
/// 将 ImportExportService 注册到插件系统的依赖注入容器
/// ImportExportService 依赖 ConverterService, NodeService 和 GraphService
class ImportExportServiceBinding extends ServiceBinding<ImportExportService> {
  @override
  ImportExportService createService(ServiceResolver resolver) {
    final converterService = resolver.get<ConverterService>();
    final nodeService = resolver.get<NodeService>();
    final graphService = resolver.get<GraphService>();
    return ImportExportServiceImpl(converterService, nodeService, graphService);
  }
}
