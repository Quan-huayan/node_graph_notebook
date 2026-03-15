// 插件系统核心导出

// 基础接口和类
export 'plugin_base.dart'
    show Plugin, internal;
export 'plugin_metadata.dart'
    show
        PluginMetadata,
        PluginType,
        PluginPermission,
        PluginState,
        PluginDependency,
        APIDependency;
export 'plugin_context.dart'
    show
        PluginContext,
        PluginLogger,
        LogLevel,
        PluginAPIProvider,
        StorageAPI,
        UIAPI,
        MenuItem,
        WidgetBuilder;
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

// 管理和生命周期
export 'plugin_manager.dart'
    show PluginManager, IPluginManager;
export 'plugin_registry.dart'
    show PluginRegistry;
export 'plugin_lifecycle.dart'
    show
        PluginLifecycleManager,
        PluginStateListener,
        PluginWrapper;
export 'plugin_discoverer.dart'
    show PluginDiscoverer, PluginFactory;

// 依赖解析
export 'dependency_resolver.dart'
    show DependencyResolver, DependencyResolutionResult;
