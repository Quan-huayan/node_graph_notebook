import '../../../../core/plugin/service_binding.dart';
import 'layout_service.dart';

/// LayoutService 绑定
///
/// 将 LayoutService 注册到插件系统的依赖注入容器
class LayoutServiceBinding extends ServiceBinding<LayoutService> {
  @override
  LayoutService createService(ServiceResolver resolver) => LayoutServiceImpl();
}
