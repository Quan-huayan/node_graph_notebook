// 插件系统核心导出

// 依赖解析
export 'dependency_resolver.dart'
    show DependencyResolver, DependencyResolutionResult;
// 基础接口和类
export 'plugin_base.dart' show Plugin, internal;
export 'plugin_context.dart'
    show
        PluginContext,
        PluginLogger,
        PluginAPIProvider,
        StorageAPI,
        UIAPI,
        MenuItem,
        WidgetBuilder;
export 'plugin_discoverer.dart' show PluginDiscoverer, PluginFactory;
export 'plugin_exception.dart'
    show
        PluginException,
        PluginNotFoundException,
        PluginAlreadyExistsException,
        PluginLoadException,
        PluginEnableException,
        PluginDisableException,
        PluginUnloadException,
        PluginDependencyException,
        CircularDependencyException,
        MissingDependencyException,
        DependencyVersionException,
        PluginPermissionException,
        PluginStateException,
        PluginConfigurationException,
        PluginVersionException,
        PluginApiException;
export 'plugin_lifecycle.dart'
    show PluginLifecycleManager, PluginStateListener, PluginWrapper;
// 管理和生命周期
export 'plugin_manager.dart' show PluginManager, IPluginManager;
export 'plugin_metadata.dart'
    show
        PluginMetadata,
        PluginType,
        PluginPermission,
        PluginState,
        PluginDependency,
        APIDependency;
export 'plugin_registry.dart' show PluginRegistry;
// Service 注册系统
export 'service_binding.dart'
    show ServiceBinding, ServiceResolver, ServiceDependencyException;
export 'service_registry.dart'
    show ServiceRegistry, ServiceRegistrationException, ServiceNotFoundException;
// DI
export 'dynamic_provider_widget.dart'
    show DynamicProviderWidget;
// 日志级别
export '../middleware/logging_middleware.dart' show LogLevel;
