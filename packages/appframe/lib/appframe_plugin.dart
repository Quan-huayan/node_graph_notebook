import 'package:core/core.dart' hide Plugin, PluginMetadata, PluginContext;
import 'package:plugin/plugin.dart' hide HookRoleRegistry;
import 'package:shared_preferences/shared_preferences.dart';

import 'service/storage_path_service.dart';
import 'theme/theme_service.dart';

/// AppFrame 插件 — 注册应用框架层服务。
///
/// 注册 ThemeService、StoragePathService、ThemeRegistry，
/// 以及 RootLayoutHook 和 SidebarLayoutHook。
class AppFramePlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'appframe',
    name: 'App Frame',
    version: '1.0.0',
    description: 'Application framework: theme, layout, storage paths.',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
    dependencies: ['core'],
  );

  @override
  List<ServiceRegistration> registerServices() => [
    ServiceRegistration.notifier<ThemeRegistry>(ThemeRegistry(), owner: metadata.id),
    ServiceRegistration.notifierFactory<ThemeService>(
      (_) { final s = ThemeService(); s.init().catchError((_) {}); return s; },
      owner: metadata.id,
    ),
    ServiceRegistration.notifierFactory<StoragePathService>(
      (reg) => StoragePathService(reg.get<SharedPreferences>()),
      owner: metadata.id,
    ),
  ];

  // AppFrame 的布局 Hooks (RootLayoutHook, SidebarLayoutHook) 由
  // AppFrameInitializer 在初始化阶段注册。
  @override
  List<HookFactory> registerHooks() => [];
}
