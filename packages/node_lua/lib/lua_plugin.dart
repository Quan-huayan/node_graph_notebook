/// LuaPlugin —— Lua 动态 Concept 引擎（M7，01-E 承诺落地）。
///
/// Lua = 动态 Concept 引擎：data/lua_scripts/*.lua 脚本定义 Concept
/// （validate/createHook 用 Lua 实现）与命令处理（Commands 表）。
/// 宿主写 API（`host.node_create/update/delete`）经单 C 回调转成
/// LuaWriteCommand → Dart Handler 落盘（00 不变量 4.4-1 的 Lua 侧落地，
/// 写操作唯一执行者仍是 Dart）。
///
/// 隔离：坏脚本跳过（不影响其他脚本/宿主）；沙箱禁用危险 API；
/// 脚本概念 owner 清理随插件卸载（plugon removeOwner）。
library;

import 'dart:io';

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:plugon/plugon.dart';

import 'src/lua_commands.dart';
import 'src/lua_concept.dart';
import 'src/lua_engine.dart';
import 'src/lua_handlers.dart';
import 'src/lua_script_loader.dart';

/// Lua 插件。
class LuaPlugin extends Plugin {
  /// 插件实例。
  ///
  /// [scriptsDir] 脚本目录（缺省 = 运行目录 data/lua_scripts）；
  /// [servicesProvider] 宿主最新 provider 入口（M7 修正，见
  /// HostRuntime.serviceProvider；缺省 = onLoad 快照，兼容单插件测试）。
  LuaPlugin({
    Directory? scriptsDir,
    ServiceProvider Function()? servicesProvider,
  }) : _scriptsDir = scriptsDir,
       _servicesProvider = servicesProvider;

  final Directory? _scriptsDir;
  final ServiceProvider Function()? _servicesProvider;

  ServiceProvider? _snapshot;
  LuaEngine? _engine;

  /// 引擎（测试可注入）。
  LuaEngine get engine => _engine!;

  /// 脚本加载错误记录（调试/日志）。
  final List<String> scriptErrors = <String>[];

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.lua',
    name: 'Lua 插件',
    version: '1.0.0',
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    _snapshot = context.services;
    final engine = LuaEngine();
    try {
      engine.initialize();
    } on LuaEngineException catch (e) {
      // dll 缺失/引擎不可用 → 插件降级为无脚本（不崩溃启动，
      // 架构 §8 隔离失败思路）。记录错误供诊断。
      scriptErrors.add('Lua 引擎不可用: ${e.message}');
      return;
    }
    _engine = engine;
    // 宿主写 API（单 C 回调分发，返回值 = 字符串通道）。
    // **同步执行**（M7 修正）：C 回调无法 await dispatch——写逻辑本身
    // 无异步（Graph 同步落盘），经 LuaWriteHandler.applySync 直接执行，
    // 写后通知经 CommandBus.notifyListeners 广播（语义与 dispatch 一致）。
    engine.registerHostFunction('node_create', (args) {
      try {
        return _hostWriteSync(action: 'create', payload: args.firstOrNull);
      } catch (e) {
        return 'error:$e';
      }
    });
    engine.registerHostFunction('node_update', (args) {
      try {
        return _hostWriteSync(action: 'update', payload: args.firstOrNull);
      } catch (e) {
        return 'error:$e';
      }
    });
    engine.registerHostFunction('node_delete', (args) {
      try {
        return _hostWriteSync(action: 'delete', payload: args.firstOrNull);
      } catch (e) {
        return 'error:$e';
      }
    });
  }

  /// 脚本目录（缺省 = 运行目录 data/lua_scripts，00 数据根约定）。
  Directory get _scriptDir {
    final override = _scriptsDir;
    if (override != null) {
      return override;
    }
    final cwd = Directory.current.path;
    return Directory(
      '$cwd${Platform.pathSeparator}data'
      '${Platform.pathSeparator}lua_scripts',
    );
  }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    _extensions = registry;
    // 宿主写 Handler（Lua host.* API 的执行者——registerExtensions 阶段
    // 即注册；graphProvider 延迟解析）。实例保留：宿主 API 同步执行用。
    final writeHandler = LuaWriteHandler(
      graphProvider: () => _services.get<Graph>(),
    );
    _writeHandler = writeHandler;
    registry.addContribution(
      commandHandlerPoint,
      writeHandler,
      ownerPluginId: metadata.id,
    );
    // 脚本命令 Handler（引擎延迟解析：registerExtensions 阶段引擎未
    // 初始化——plugon 顺序 registerServices → registerExtensions → onLoad；
    // Commands 路由表在 onEnable 脚本加载后填充）。
    final commandHandler = LuaCommandHandler(engineProvider: () => _engine);
    registry.addContribution(
      commandHandlerPoint,
      commandHandler,
      ownerPluginId: metadata.id,
    );
    _commandHandler = commandHandler;
  }

  LuaCommandHandler? _commandHandler;

  /// 服务解析：宿主入口（运行时最新）优先；缺省回退 onLoad 快照。
  ServiceProvider get _services => _servicesProvider?.call() ?? _snapshot!;

  /// 启用：加载脚本（onLoad 后引擎就绪；动态 Concept 运行时贡献）。
  ///
  /// 注：Concept 贡献在 enablePlugin（依赖就绪后）添加——plugon
  /// removeOwner 卸载时自动清理。
  @override
  Future<void> onEnable() async {
    final engine = _engine;
    if (engine == null) {
      return; // 引擎不可用 → 无脚本（已记录错误）。
    }
    final loader = LuaScriptLoader(engine: engine);
    final results = loader.loadAll(_scriptDir.path);
    for (final result in results) {
      if (!result.ok) {
        scriptErrors.add('脚本 ${result.scriptId} 加载失败: ${result.error}');
        continue;
      }
      // 动态 Concept 运行时贡献（owner = 本插件，卸载自动清理）。
      _extensions!.addContribution(
        conceptPoint,
        result.concept!,
        ownerPluginId: metadata.id,
      );
      _concepts[result.scriptId] = result.concept!;
    }
    // 命令路由表（Commands 表 → LuaCommandHandler）。
    _commandHandler?.commandNames.addAll(loader.commandNames());
  }

  /// 脚本目录内加载的 Concept（scriptId → Concept，调试/测试）。
  final Map<String, LuaConcept> _concepts = <String, LuaConcept>{};

  /// 已加载的脚本 Concept。
  Map<String, LuaConcept> get concepts => Map.unmodifiable(_concepts);

  /// 扩展注册表（onLoad 后可用；动态 Concept 运行时贡献的目标）。
  ExtensionRegistry? get extensions => _extensions;

  ExtensionRegistry? _extensions;

  /// 宿主写 API → LuaWriteHandler 同步执行 + 写后广播（M7 修正：
  /// C 回调无法 await——写逻辑同步完成，结果字符串通道返回）。
  String _hostWriteSync({required String action, required dynamic payload}) {
    final map = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
    final result = _writeHandler!.applySync(
      LuaWriteCommand(
        action: action,
        nodeId: map['id'] as String?,
        title: map['title'] as String?,
        content: map['content'] as String?,
        references: _stringMap(map['references']),
        metadata: map['metadata'] is Map<String, dynamic>
            ? map['metadata'] as Map<String, dynamic>
            : null,
      ),
    );
    // 写后通知（03 §四：写完成 → 监听者——与 dispatch 广播一致）。
    (_services.get<CommandBus>() as PluginCommandBus).notifyListeners(result);
    return 'affected:${result.affectedNodeIds.join(',')};structure';
  }

  LuaWriteHandler? _writeHandler;

  Map<String, String> _stringMap(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const <String, String>{};
    }
    return value.map((k, v) => MapEntry(k, v.toString()));
  }

  @override
  Future<void> onDisable() async {
    // 贡献停用由 plugon 处理（setPluginActive）——动态 Concept 随
    // 插件停用进入兜底渲染（永不空洞，00 不变量 4.3-3）。
  }

  @override
  Future<void> onUnload() async {
    _engine?.dispose();
    _engine = null;
    _concepts.clear();
  }
}
