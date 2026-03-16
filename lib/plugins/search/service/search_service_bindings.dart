import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/plugin/service_binding.dart';
import 'search_preset_service.dart';

/// SearchPresetService 绑定
///
/// 将 SearchPresetService 注册到插件系统的依赖注入容器
class SearchPresetServiceBinding extends ServiceBinding<SearchPresetService> {
  @override
  SearchPresetService createService(ServiceResolver resolver) {
    final prefs = resolver.get<SharedPreferencesAsync>();
    return SearchPresetServiceImpl(prefs);
  }
}
