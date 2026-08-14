import 'package:core/core.dart' hide Plugin, PluginManager;
import 'package:flutter/material.dart';
import 'package:plugin/plugin.dart';

import 'command/create_lua_script_command.dart';
import 'command/delete_lua_script_command.dart';
import 'command/execute_lua_script_command.dart';
import 'command/toggle_lua_script_command.dart';
import 'command/update_lua_script_command.dart';
import 'handler/create_lua_script_handler.dart';
import 'handler/delete_lua_script_handler.dart';
import 'handler/execute_lua_script_handler.dart';
import 'handler/toggle_lua_script_handler.dart';
import 'handler/update_lua_script_handler.dart';
import 'service/lua_api_implementation.dart';
import 'service/lua_command_server.dart';
import 'service/lua_dynamic_hook_manager.dart';
import 'service/lua_engine_service.dart';
import 'service/lua_script_service.dart';
import 'service/lua_security_manager.dart';

/// The Lua scripting plugin providing automation and extensibility via Lua
/// scripts, including a sandboxed engine, dynamic UI hooks, and a command
/// server for external communication.
class LuaPlugin extends Plugin {
  LuaEngineService? _engineService;
  LuaAPIImplementation? _apiImplementation;
  LuaScriptService? _scriptService;
  LuaDynamicHookManager? _dynamicHookManager;
  LuaCommandServer? _commandServer;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'lua',
    name: 'Lua Scripting',
    version: '1.0.0',
    description: 'Lua scripting support for automation and extensibility',
    author: 'Node Graph Notebook',
  );

  @override
  List<ServiceRegistration> registerServices() => [];

  @override
  Future<void> onLoad(PluginContext context) async {
    try {
      _engineService = LuaEngineService(
        enableSandbox: true,
        enableDebugOutput: true,
        sandboxConfig: LuaSandboxConfig.permissive(),
      );
      await _engineService!.initialize();

      _apiImplementation = LuaAPIImplementation(
        engineService: _engineService!,
        nodeRepository: context.get<NodeRepository>(),
        graphRepository: context.get<GraphRepository>(),
      );
      _apiImplementation!.registerAllAPIs();

      _scriptService = context.get<LuaScriptService>();
      await _scriptService!.initialize();

      _dynamicHookManager = LuaDynamicHookManager(
        engineService: _engineService!,
        hookRegistry: context.get<HookRoleRegistry>(),
      );
      _dynamicHookManager!.registerAPIs();

      _registerCommandHandlers(context);
      debugPrint('[LuaPlugin] Lua plugin loaded');
    } catch (e) {
      debugPrint('[LuaPlugin] Lua plugin load failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> onEnable() async {
    if (_engineService != null && _scriptService != null) {
      _commandServer = LuaCommandServer(engineService: _engineService!);
      await _commandServer!.start();
    }
  }

  @override
  Future<void> onDisable() async {
    await _commandServer?.stop();
  }

  @override
  Future<void> onUnload() async {
    _dynamicHookManager?.clear();
    await _engineService?.dispose();
    await _scriptService?.dispose();
  }

  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.get<CommandBus>();
    commandBus
      ..registerHandler(ExecuteLuaScriptHandler(engineService: _engineService!, scriptService: _scriptService!), ExecuteLuaScriptCommand)
      ..registerHandler(CreateLuaScriptHandler(scriptService: _scriptService!), CreateLuaScriptCommand)
      ..registerHandler(UpdateLuaScriptHandler(scriptService: _scriptService!), UpdateLuaScriptCommand)
      ..registerHandler(DeleteLuaScriptHandler(scriptService: _scriptService!), DeleteLuaScriptCommand)
      ..registerHandler(ToggleLuaScriptHandler(scriptService: _scriptService!), ToggleLuaScriptCommand);
  }

  /// The underlying Lua engine service managing script execution and sandboxing.
  LuaEngineService? get engineService => _engineService;

  /// The script service responsible for loading, saving, and managing Lua scripts.
  LuaScriptService? get scriptService => _scriptService;

  /// The API implementation that registers Lua-accessible APIs for node and
  /// graph operations.
  LuaAPIImplementation? get apiImplementation => _apiImplementation;
}
