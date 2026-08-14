import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plugin/plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cqrs/commands/command_bus.dart';
import 'cqrs/query/query_bus.dart';
import 'execution/execution_engine.dart';
import 'execution/task_registry.dart';
import 'infrastructure/i18n.dart';
import 'infrastructure/settings_registry.dart';
import 'plugin/hook/ui_layout_service.dart';

/// Core 插件 — 注册所有核心基础设施服务。
///
/// 这些是 Node Graph Notebook 运行所必需的服务：
/// - [CommandBus] — CQRS 命令总线
/// - [QueryBus] — CQRS 查询总线
/// - [ExecutionEngine] — CPU 任务执行引擎
/// - [TaskRegistry] — 任务类型注册表
/// - [SettingsRegistry] — 设置注册表
/// - [I18n] — 国际化服务
/// - [UILayoutService] — UI 布局服务
/// - [HookRoleRegistry] — UI Hook 注册表
class CorePlugin extends Plugin {
  /// 创建 Core 插件。
  CorePlugin({
    required HookRoleRegistry hookRoleRegistry,
  }) : _hookRoleRegistry = hookRoleRegistry;

  final HookRoleRegistry _hookRoleRegistry;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'core',
    name: 'Core',
    version: '1.0.0',
    description: 'Core infrastructure services: CommandBus, QueryBus, I18n, etc.',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
  );

  @override
  List<ServiceRegistration> registerServices() => [
    // ── 无依赖服务 ──
    ServiceRegistration.singleton<CommandBus>(
      (_) => CommandBus(),
      owner: metadata.id,
    ),
    ServiceRegistration.singleton<QueryBus>(
      (_) => QueryBus(),
      owner: metadata.id,
    ),
    ServiceRegistration.singleton<TaskRegistry>(
      (_) => TaskRegistry(),
      owner: metadata.id,
    ),
    ServiceRegistration.singleton<ExecutionEngine>(
      (reg) {
        final engine = ExecutionEngine();
        engine.initialize(taskRegistry: reg.get<TaskRegistry>());
        return engine;
      },
      owner: metadata.id,
    ),

    // ── 响应式 ChangeNotifier 服务 ──
    ServiceRegistration.notifierFactory<SettingsRegistry>(
      (reg) => SettingsRegistry(reg.get<SharedPreferences>()),
      owner: metadata.id,
    ),

    // ── 依赖 CommandBus 的服务 ──
    ServiceRegistration.singleton<UILayoutService>(
      (reg) {
        final service = UILayoutService(commandBus: reg.get<CommandBus>());
        service.initialize();
        return service;
      },
      owner: metadata.id,
    ),

    ServiceRegistration.notifier<I18n>(_createI18n(), owner: metadata.id),
    ServiceRegistration.notifier<HookRoleRegistry>(_hookRoleRegistry, owner: metadata.id),
  ];

  I18n _createI18n() {
    final i18n = I18n();
    i18n.initialize().catchError((_) {});
    return i18n;
  }

  @override
  List<HookFactory> registerHooks() => [];

  @override
  List<BlocProvider> registerBlocs() => [];
}
