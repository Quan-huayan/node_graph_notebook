import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_registry.dart';
import '../../../core/repositories/node_repository.dart';
import '../../../core/repositories/graph_repository.dart';
import 'command/execute_lua_script_command.dart';
import 'command/create_lua_script_command.dart';
import 'command/update_lua_script_command.dart';
import 'command/delete_lua_script_command.dart';
import 'command/toggle_lua_script_command.dart';
import 'handler/execute_lua_script_handler.dart';
import 'handler/create_lua_script_handler.dart';
import 'handler/update_lua_script_handler.dart';
import 'handler/delete_lua_script_handler.dart';
import 'handler/toggle_lua_script_handler.dart';
import 'service/lua_engine_service.dart';
import 'service/lua_script_service.dart';
import 'service/lua_service_bindings.dart';
import 'service/lua_api_implementation.dart';
import 'service/lua_dynamic_hook_manager.dart';
import 'service/lua_command_server.dart';
import 'service/lua_security_manager.dart';

/// Lua插件
///
/// 为应用提供Lua脚本支持，允许通过脚本调用应用功能
/// 支持双引擎架构：简单引擎（兼容模式）和真正Lua引擎（完整功能）
/// 不包含UI，仅提供脚本执行和API调用能力
class LuaPlugin extends Plugin {
  PluginState _state = PluginState.loaded;

  /// Lua引擎服务
  LuaEngineService? _engineService;

  /// Lua API实现
  LuaAPIImplementation? _apiImplementation;

  /// Lua脚本服务
  LuaScriptService? _scriptService;

  /// Lua动态Hook管理器
  LuaDynamicHookManager? _dynamicHookManager;

  /// Lua命令服务器
  LuaCommandServer? _commandServer;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'lua',
        name: 'Lua Scripting',
        version: '1.0.0',
        description: 'Lua scripting support for automation and extensibility',
        author: 'Node Graph Notebook',
        enabledByDefault: true, // 默认启用
        dependencies: [], // 无依赖
      );

  @override
  List<ServiceBinding> registerServices() => [
        LuaScriptServiceBinding(),
      ];

  @override
  List<HookFactory> registerHooks() => const [];

  @override
  Future<void> onLoad(PluginContext context) async {
    try {
      // 初始化Lua引擎服务（使用真正Lua引擎）
      // 🔧 使用宽松的沙箱配置，允许注册所有 API
      _engineService = LuaEngineService(
        enableSandbox: true,
        enableDebugOutput: true,
        engineType: LuaEngineType.realLua,
        sandboxConfig: LuaSandboxConfig.permissive(), // ✅ 使用宽松模式
      );
      await _engineService!.initialize();

      // 初始化Lua API实现（连接到实际Repository）
      _apiImplementation = LuaAPIImplementation(
        engineService: _engineService!,
        nodeRepository: context.read<NodeRepository>(),
        graphRepository: context.read<GraphRepository>(),
      );
      _apiImplementation!.registerAllAPIs();

      // LuaScriptService通过依赖注入获取，但需要手动初始化
      _scriptService = context.read<LuaScriptService>();
      await _scriptService!.initialize();

      // 初始化动态Hook管理器（使用全局hookRegistry）
      _dynamicHookManager = LuaDynamicHookManager(
        engineService: _engineService!,
        hookRegistry: hookRegistry,
      );
      _dynamicHookManager!.registerAPIs();

      // 注册命令处理器
      _registerCommandHandlers(context);

      context.logger?.info('Lua插件加载成功');
    } catch (e) {
      context.logger?.error('Lua插件加载失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> onEnable() async {
    // 启用时的逻辑
    if (_engineService != null && _scriptService != null) {
      // 启动命令服务器
      _commandServer = LuaCommandServer(
        engineService: _engineService!,
      );
      await _commandServer!.start();
    }
  }

  @override
  Future<void> onDisable() async {
    // 禁用时的逻辑
    await _commandServer?.stop();
  }

  @override
  Future<void> onUnload() async {
    try {
      // 清理动态Hook
      _dynamicHookManager?.clear();

      // 释放资源
      await _engineService?.dispose();
      await _scriptService?.dispose();
    } catch (e) {
      // 静默处理错误
    }
  }

  /// 注册命令处理器
  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.commandBus;

    // 注册Lua脚本执行命令处理器
    commandBus.registerHandler(
      ExecuteLuaScriptHandler(
        engineService: _engineService!,
        scriptService: _scriptService!,
      ),
      ExecuteLuaScriptCommand,
    );

    // 注册Lua脚本CRUD命令处理器
    commandBus.registerHandler(
      CreateLuaScriptHandler(
        scriptService: _scriptService!,
      ),
      CreateLuaScriptCommand,
    );

    commandBus.registerHandler(
      UpdateLuaScriptHandler(
        scriptService: _scriptService!,
      ),
      UpdateLuaScriptCommand,
    );

    commandBus.registerHandler(
      DeleteLuaScriptHandler(
        scriptService: _scriptService!,
      ),
      DeleteLuaScriptCommand,
    );

    commandBus.registerHandler(
      ToggleLuaScriptHandler(
        scriptService: _scriptService!,
      ),
      ToggleLuaScriptCommand,
    );
  }

  /// 获取Lua引擎服务实例
  ///
  /// 主要用于测试访问
  LuaEngineService? get engineService => _engineService;

  /// 获取Lua脚本服务实例
  ///
  /// 主要用于测试访问
  LuaScriptService? get scriptService => _scriptService;

  /// 获取Lua API实现实例
  ///
  /// 主要用于测试访问
  LuaAPIImplementation? get apiImplementation => _apiImplementation;
}
