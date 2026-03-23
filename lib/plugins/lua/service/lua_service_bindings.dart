import '../../../../core/plugin/service_binding.dart';
import 'lua_script_service.dart';

/// LuaScriptService 绑定
///
/// 将 LuaScriptService 注册到插件系统的依赖注入容器
class LuaScriptServiceBinding extends ServiceBinding<LuaScriptService> {
  @override
  LuaScriptService createService(ServiceResolver resolver) {
    return LuaScriptService();
  }
}
