# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Node Graph Notebook** is a Flutter-based concept-map visualization notebook that rethinks note organization using a node-based architecture. The core philosophy is "All is node!!" - all content elements (text, concepts, relationships) are unified as nodes with graph-based visualization powered by the Flame game engine.

### Key Features

- Node-based note organization with concept mapping
- Markdown editing and rendering
- Interactive graph visualization using Flame game engine
- AI integration framework
- Plugin system for extensibility
- Data import/export functionality
- Theme customization (light/dark modes)

## ⚠️ Architecture Implementation Status

**The project has completed a major architectural refactoring implementing Command Bus and Plugin patterns.**

### Current Status: ✅ Implementation Complete (100%)

The refactoring has successfully introduced:

- **Command Bus**: Centralized business logic execution with middleware pipeline
- **CQRS Pattern**: Complete separation of read (Repository) and write (Command) operations
- **Plugin System**: Fully functional plugin architecture with UI hooks, service providers, and middleware plugins
- **BLoC Restructuring**: BLoCs now only manage UI state, all business logic in Command Handlers
- **Event-Driven Architecture**: EventBus for cross-component communication
- **Unified DI Container**: Single dependency injection system supporting both Provider and dynamic plugin loading

### Implementation Summary

**Completed Components:**
- ✅ Core Command Bus infrastructure (`lib/core/commands/`)
- ✅ Command Handler system with 15+ handlers
- ✅ Middleware system (Logging, Validation, Transaction, Undo)
- ✅ Plugin Manager with lifecycle management
- ✅ UI Hook system with HookRegistry
- ✅ NodeBloc refactored to use CommandBus
- ✅ Service Registry for plugin-provided services
- ✅ API Registry for inter-plugin communication
- ✅ Unified DI Container (ServiceRegistry + DynamicProviderWidget)
- ✅ Lazy loading support for non-critical services

**Remaining Work:**
- ⏳ Test coverage for new Command Handlers
- ⏳ Performance optimization for large datasets
- ⏳ Documentation updates for plugin development

### Key Architecture Changes

**New Architecture:**
```
UI Layer (Widgets)
    ↓
BLoC Layer (UI State Management)
    ↓
CommandBus (Business Logic Gateway)
    ↓
Command Handlers (Business Logic)
    ↓
Services/Repositories (Data Access)
```

**Important Patterns:**
- ✅ **Write operations** → Use `CommandBus.dispatch(command)`
- ✅ **Read operations** → Use `Repository` directly
- ✅ **BLoCs** → Only manage UI state (isLoading, error, selection)
- ✅ **EventBus** → Subscribe to data changes from other components
- ✅ **Plugins** → Extend functionality via hooks, services, and middleware

### Working with the Current Architecture

#### Adding New Commands

1. Create command class in `lib/plugins/{plugin_name}/command/`
2. Create handler in `lib/plugins/{plugin_name}/handler/`
3. Register handler in plugin's `registerCommandHandlers()` method
4. Use in BLoC via `commandBus.dispatch(command)`

**Example:**
```dart
// Define command
class MyCommand extends Command<Result> {
  final String param;
  MyCommand(this.param);

  @override
  Future<void> execute(CommandContext context) async {
    // Command logic
  }
}

// Define handler
class MyCommandHandler extends CommandHandler<MyCommand> {
  @override
  Future<CommandResult<Result>> execute(
    MyCommand command,
    CommandContext context,
  ) async {
    // Business logic
    return CommandResult.success(result);
  }
}

// Register in plugin
@override
List<CommandHandlerBinding> registerCommandHandlers() {
  return [
    CommandHandlerBinding(MyCommand, () => MyCommandHandler()),
  ];
}

// Use in BLoC
final result = await _commandBus.dispatch(MyCommand('value'));
```

#### Adding New Middleware

1. Create middleware class implementing `CommandMiddleware`
2. Implement `processBefore()` and/or `processAfter()` methods
3. Register in plugin's `registerMiddleware()` method or in `app.dart`

**Example:**
```dart
class MyMiddleware implements CommandMiddleware {
  @override
  Future<void> processBefore(
    Command command,
    CommandContext context,
  ) async {
    // Pre-processing logic
  }

  @override
  Future<void> processAfter(
    Command command,
    CommandContext context,
    CommandResult result,
  ) async {
    // Post-processing logic
  }
}
```

#### Creating Plugins

**Plugin Types:**
1. **Service Plugins** - Provide business logic services
2. **UI Hook Plugins** - Extend UI at specific hook points
3. **Middleware Plugins** - Intercept command processing

**Example Plugin:**
```dart
class MyPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.myPlugin',
    name: 'My Plugin',
    version: '1.0.0',
    dependencies: [],
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    // Initialize plugin
  }

  @override
  List<CommandHandlerBinding> registerCommandHandlers() {
    return [
      // Register command handlers
    ];
  }

  @override
  List<ServiceBinding> registerServices() {
    return [
      // Register services
    ];
  }
}
```

### Related Files

**Command Bus Core:**
- `lib/core/commands/command.dart` - Command base classes
- `lib/core/commands/command_bus.dart` - Command bus implementation
- `lib/core/commands/command_context.dart` - Execution context
- `lib/core/commands/command_handler.dart` - Handler interface

**Plugin System:**
- `lib/core/plugin/plugin.dart` - Plugin base interface
- `lib/core/plugin/plugin_manager.dart` - Plugin lifecycle management
- `lib/core/plugin/ui_hooks/` - UI hook system
- `lib/plugins/` - Built-in plugin implementations

**Middleware:**
- `lib/plugins/builtin_middlewares/logging_middleware.dart`
- `lib/plugins/builtin_middlewares/validation_middleware.dart`
- `lib/plugins/builtin_middlewares/transaction_middleware.dart`
- `lib/plugins/builtin_middlewares/undo_middleware.dart`

**BLoC Examples:**
- `lib/plugins/graph/bloc/node_bloc.dart` - Refactored NodeBloc

## Development Commands

### Essential Commands

```bash
# Install dependencies
flutter pub get

# Generate JSON serialization code (required after model changes)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Run tests
flutter test

# Code analysis (use scripts to filter third-party warnings)
bash scripts/analyze.sh    # Unix/macOS
.\scripts\analyze.bat      # Windows

# Full build (includes analysis and tests)
bash scripts/build.sh      # Unix/macOS
.\scripts\build.bat        # Windows

# Build Windows release
flutter build windows

# Format code
dart format .
```

### Before Running

After pulling changes or modifying models in `lib/core/models/`, always run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Architecture

The application follows **Clean Architecture** with a **hybrid BLoC + Provider** state management pattern. The dependency injection order is critical:

### Dependency Layers (in order)

```txt
Repository Layer (data access)
    ↓
Service Layer (business logic)
    ↓
BLoC Layer (state management)
    ↓
UI Layer (widgets)
```

**Note:** Provider is still used for services and some models, while BLoC manages complex state logic.

### Key Architectural Patterns

**1. "Everything is a Node" Philosophy**

- All content inherits from base `Node` class
- Node types: `concept`, `content`, `folder`, etc.
- Relationships managed through `NodeReference` objects
- Position and size tracked for visual layout

**2. Provider/BLoC Organization** (see `lib/app.dart`)

The application initializes dependencies in strict layers using **DynamicProviderWidget**:

```dart
// 1. Create ServiceRegistry with core dependencies
_serviceRegistry = ServiceRegistry(
  coreDependencies: {
    NodeRepository: _nodeRepository,
    GraphRepository: _graphRepository,
    CommandBus: _commandBus,
    AppEventBus: _eventBus,
    SettingsService: widget.settingsService,
    ThemeService: widget.themeService,
  },
);

// 2. Use DynamicProviderWidget to wrap MultiProvider
DynamicProviderWidget(
  serviceRegistry: _serviceRegistry,
  coreProviders: [
    // === Core System Providers ===
    // 0. Settings & Theme Services (must be first - plugins may depend on these)
    ChangeNotifierProvider<SettingsService>.value(...),
    ChangeNotifierProvider<ThemeService>.value(...),
    Provider<SharedPreferencesAsync>...,

    // 1. Repository Layer (data access - foundation for all services)
    Provider<NodeRepository>.value(...),
    Provider<GraphRepository>.value(...),

    // 2. Event Bus (for cross-component communication)
    Provider<AppEventBus>.value(...),

    // 3. Command Bus (business logic gateway)
    Provider<CommandBus>.value(...),

    // === Core UI BLoCs ===
    // 4. UI BLoC (core UI state management)
    BlocProvider<UIBloc>...,

    // === Plugin System Providers ===
    // 5. Hook Registry (global singleton for UI extensions)
    Provider<HookRegistry>...,

    // 6. Plugin Manager (plugin lifecycle management)
    Provider<PluginManager>.value(...),

    // === Plugin BLoC Layer ===
    // 7. Plugin-provided BLoCs (auto-generated from plugins)
    ...pluginManager.generateBlocProviders(),
  ],
  child: MaterialApp(...),
)
```

**Critical Dependency Order:**
1. **ServiceRegistry** first - must be created before any plugins
2. **Settings/Theme** second - plugins may need these during initialization
3. **Repositories** third - all services depend on data access
4. **EventBus** fourth - command handlers and services need event publishing
5. **CommandBus** fifth - handlers need all services registered first
6. **UI BLoC** sixth - core UI state management
7. **Plugin System** seventh - HookRegistry and PluginManager orchestrate everything
8. **Plugin BLoCs** eighth - plugin BLoCs depend on plugin services

**Key Changes from Old Architecture:**
- **DynamicProviderWidget** replaces static MultiProvider
- **ServiceRegistry** unifies all DI systems
- Plugin services are automatically added to Provider tree
- Provider tree rebuilds when plugins load/unload
- No need to manually add plugin providers

**Plugin Loading Process:**
1. **Initialization Phase** (`app.dart:147-152`)
   - Create ServiceRegistry with core dependencies
   - Pass CommandBus, EventBus, Repositories to plugins

2. **Loading Phase** (`app.dart:155-177`)
   - FutureBuilder waits for `_loadPlugins()` to complete
   - Shows "Loading plugins..." screen during initialization
   - BuiltinPluginLoader loads all built-in plugins

3. **Discovery & Registration** (`builtin_plugin_loader.dart`)
   - PluginDiscoverer instantiates plugins via factory functions
   - DependencyResolver determines load order (topological sort)
   - Plugins loaded according to dependency relationships

4. **Plugin Lifecycle** (`plugin_manager.dart:102-183`)
   - `loadPlugin()` → Register plugin services to ServiceRegistry
   - Call `plugin.onLoad(context)` - **can now access plugin's own services!**
   - Register plugin APIs to APIRegistry
   - Validate plugin dependencies

5. **Provider Generation** (`app.dart:207-210`)
   - `DynamicProviderWidget` automatically includes plugin services
   - `pluginManager.generateBlocProviders()` - Create providers for plugin BLoCs
   - Provider tree rebuilds when services change

6. **UI Extension** (after DynamicProviderWidget)
   - UI Hook plugins render widgets at hook points via HookRegistry
   - Hook points are now string-based IDs (e.g., 'main.toolbar', 'sidebar.bottom')
   - Hooks use UIHookBase (not Plugin), with simplified lifecycle
   - Hook priority uses semantic enums (critical, high, medium, low, decorative)
   - Hooks can export APIs for inter-hook communication via HookAPIRegistry
   - Dynamic hook point registration supported via HookPointRegistry

**Key Points:**
- Plugins are loaded **before** UI renders, ensuring all services available
- Plugin services are injected into Provider tree automatically via DynamicProviderWidget
- Plugin BLoCs are registered alongside core BLoCs
- UI Hooks extend UI at specific points via HookRegistry
- Dependency order is enforced via topological sorting
- **Plugins can now access their own services in onLoad()** - major improvement!

**3. Provider/BLoC Usage Rules**

**Provider:**
- `context.watch<T>()` - when widget needs to rebuild on state changes
- `context.read<T>()` - for callbacks/event handlers (no rebuild)
- `context.select<T, R>()` - watch specific properties only

**BLoC:**
- `context.watch<BlocCubit<T>>()` - rebuild on state changes
- `context.read<BlocCubit<T>>()` - access bloc without rebuild (for event handlers)
- Use `BlocBuilder` for rebuilding widgets based on bloc state
- Use `BlocListener` for side effects (navigation, showing dialogs)
- Use `BlocConsumer` when both rebuilding and side effects are needed

### BLoC Architecture

The application uses **BLoC (Business Logic Component)** pattern for state management. After refactoring, BLoCs are organized differently:

**BLoC Location Changes:**
- **Core UI BLoCs** (`lib/ui/bloc/`):
  - `UIBloc` - Manages UI state (sidebar, panels, dialogs)

- **Plugin-Provided BLoCs** (`lib/plugins/{plugin}/bloc/`):
  - `NodeBloc` (Graph plugin) - Manages node state
  - `GraphBloc` (Graph plugin) - Manages graph state
  - Other domain-specific BLoCs provided by plugins

**BLoC Responsibilities (After Refactoring):**

```dart
// ✅ CORRECT: BLoC manages UI state only
class NodeBloc extends Bloc<NodeEvent, NodeState> {
  Future<void> _onCreateNode(NodeCreateEvent event, Emitter emit) async {
    emit(state.copyWith(isLoading: true));

    // Write operations go through CommandBus
    final result = await _commandBus.dispatch(CreateNodeCommand(...));

    if (result.isSuccess) {
      // Update UI state based on result
      emit(state.copyWith(
        nodes: [...state.nodes, result.data],
        isLoading: false,
      ));
    } else {
      emit(state.copyWith(isLoading: false, error: result.error));
    }
  }

  Future<void> _onLoadNodes(NodeLoadEvent event, Emitter emit) async {
    // Read operations go directly to Repository
    final nodes = await _nodeRepository.queryAll();
    emit(state.copyWith(nodes: nodes));
  }
}

// ❌ WRONG: Business logic in BLoC
class NodeBloc extends Bloc<NodeEvent, NodeState> {
  Future<void> _onCreateNode(NodeCreateEvent event, Emitter emit) async {
    // Don't do this! Business logic belongs in Command Handlers
    final node = Node(id: uuid.v4(), title: event.title);
    await _nodeRepository.save(node);
    await _graphService.addNodeToGraph(node.id);
    emit(state.copyWith(nodes: [...state.nodes, node]));
  }
}
```

**Event Bus Pattern** (`lib/core/events/app_events.dart`):

The `AppEventBus` enables **cross-component communication**:

```dart
// Command Handlers publish events after operations
eventBus.publish(NodeDataChangedEvent(
  changedNodes: [updatedNode],
  action: DataChangeAction.update,
));

// BLoCs subscribe to EventBus for updates
eventBus.stream.listen((event) {
  if (event is NodeDataChangedEvent) {
    // React to data changes from other components
    add(NodeDataChangedInternalEvent(...));
  }
});
```

**Key Benefits:**
- **Decoupling**: Components communicate without direct dependencies
- **Reactivity**: BLoCs automatically update when data changes
- **Scalability**: Easy to add new components that subscribe to events
- **Testability**: Each component can be tested independently

**Event Types:**
- `NodeDataChangedEvent` - Nodes created/updated/deleted
- `GraphNodeRelationChangedEvent` - Node-graph relationships changed
- Custom events can be defined by plugins

**4. Command Bus Pattern**

The Command Bus is the central business logic execution engine:

**Command Definition:**
```dart
class CreateNodeCommand extends Command<Node> {
  final String title;
  final String content;

  CreateNodeCommand({required this.title, required this.content});

  @override
  Future<void> execute(CommandContext context) async {
    // Command validation/setup logic (if needed)
    // Actual business logic is in Handler
  }

  @override
  Future<void> undo(CommandContext context) async {
    // Undo logic (optional - for undoable commands)
  }
}
```

**Command Handler:**
```dart
class CreateNodeHandler extends CommandHandler<CreateNodeCommand> {
  final NodeRepository _repository;
  final AppEventBus _eventBus;

  CreateNodeHandler(this._repository, this._eventBus);

  @override
  Future<CommandResult<Node>> execute(
    CreateNodeCommand command,
    CommandContext context,
  ) async {
    // Business logic implementation
    final node = Node(
      id: uuid.v4(),
      title: command.title,
      content: command.content,
    );

    await _repository.save(node);

    // Publish event for other components
    _eventBus.publish(NodeDataChangedEvent(
      changedNodes: [node],
      action: DataChangeAction.create,
    ));

    return CommandResult.success(node);
  }
}
```

**Command Execution Flow:**
```
UI → BLoC → CommandBus.dispatch()
              ↓
         [Middleware Pipeline]
              ↓
         CommandHandler.execute()
              ↓
         Service/Repository
              ↓
         [Publish Events]
              ↓
         CommandResult<T>
```

**Middleware Pipeline:**
```dart
// Middleware can intercept before/after command execution
class LoggingMiddleware implements CommandMiddleware {
  @override
  Future<void> processBefore(Command cmd, CommandContext ctx) async {
    debugPrint('Executing: ${cmd.name}');
  }

  @override
  Future<void> processAfter(
    Command cmd,
    CommandContext ctx,
    CommandResult result,
  ) async {
    debugPrint('Result: ${result.isSuccess ? "Success" : "Failed"}');
  }
}
```

**Command Locations:**
- Commands: `lib/plugins/{plugin}/command/`
- Handlers: `lib/plugins/{plugin}/handler/`
- Middleware: `lib/plugins/builtin_middlewares/`

### Core Components

**Data Layer** (`lib/core/`)

- `models/` - Core data models (Node, Graph, NodeReference, Connection, etc.)
  - `Connection` - Defines relationships between nodes (computed from NodeReference)
- `repositories/` - File-based data persistence
  - `FileSystemNodeRepository` - Node storage as Markdown files
  - `FileSystemGraphRepository` - Graph storage as JSON files
  - `MetadataIndex` - Efficient node metadata indexing for fast lookups
- `commands/` - Command Bus system
  - `command.dart` - Command base classes and interfaces
  - `command_bus.dart` - Central command dispatcher with middleware pipeline
  - `command_context.dart` - Execution context for commands
  - `command_handler.dart` - Handler interface for commands
- `events/` - Event bus system for cross-component communication
  - `AppEventBus` - Singleton broadcast stream for decoupled communication
- `plugin/` - Plugin system core
  - `plugin.dart` - Base Plugin interface and lifecycle
  - `plugin_manager.dart` - Plugin lifecycle management
  - `plugin_discoverer.dart` - Plugin discovery and instantiation
  - `builtin_plugin_loader.dart` - Built-in plugin loader
  - `ui_hooks/` - UI Hook system
  - `api/` - API registry for inter-plugin communication
  - `middleware/` - Middleware plugin support

**Plugin-Based Services** (`lib/plugins/`)

**Graph Plugin** (`graph/`):
- `bloc/node_bloc.dart` - Node state management
- `bloc/graph_bloc.dart` - Graph state management
- `command/node_commands.dart` - Node-related commands
- `handler/*` - Command handlers (15+ handlers for node/graph operations)
- `service/` - Graph-specific services

**Layout Plugin** (`layout/`):
- `handler/apply_layout_handler.dart` - Layout algorithm commands
- Service providers for graph layout

**AI Plugin** (`ai/`):
- `handler/analyze_node_handler.dart` - AI analysis commands
- Service providers for AI integration
- UI Hooks for AI features

**Converter Plugin** (`converter/`):
- Import/export functionality
- Format conversion services

**Middlewares** (`builtin_middlewares/`):
- `logging_middleware.dart` - Command execution logging
- `validation_middleware.dart` - Command validation
- `transaction_middleware.dart` - Transaction management
- `undo_middleware.dart` - Undo/redo stack management

**UI Layer** (`lib/ui/`)

- `bloc/ui_bloc.dart` - Core UI state management
- `models/` - State management models (NodeModel, GraphModel, UIModel)
- `pages/` - Full-screen pages
- `widgets/` - Reusable components
- `dialogs/` - Dialogs and modals
- `views/` - View widgets (graph view, folder tree, etc.)
- Hook points for plugin extension

**Visualization** (`lib/flame/`)

- Flame engine components for interactive node graphs
- Custom rendering and interaction handling

**Converter Layer** (`lib/converter/`)

- Format conversion between internal and external formats
- Markdown with YAML frontmatter support for round-trip editing

**Plugin System** (`lib/core/plugin/` & `lib/plugins/`)

The application features a comprehensive plugin system for extensibility:

**Plugin Architecture:**
- **Plugin Manager** - Manages plugin lifecycle, dependencies, and loading order
- **Plugin Discoverer** - Discovers and instantiates plugins via factory functions
- **Dependency Resolver** - Resolves plugin dependencies using topological sorting
- **Plugin Registry** - Maintains registry of all loaded plugins
- **Hook Registry** - Manages UI hooks for extending application UI (NEW: UIHookBase system)

**UI Hook System (Refactored 2026-03-17):**

The UI Hook system has been refactored to separate concerns:

**Key Components:**
- `UIHookBase` - Base class for UI hooks (no longer extends Plugin)
- `HookRegistry` - Manages hook registration and lifecycle
- `HookPointRegistry` - Manages hook point definitions (supports dynamic registration)
- `HookAPIRegistry` - Manages inter-hook API communication
- `HookLifecycle` - Manages individual hook lifecycle states
- `HookMetadata` - Hook metadata (ID, name, version, description)
- `HookPriority` - Semantic priority levels (critical, high, medium, low, decorative)

**Hook Lifecycle:**
1. `onInit(context)` - Initialize hook (called once)
2. `onEnable()` - Activate hook functionality (may call multiple times)
3. `onDisable()` - Deactivate hook functionality (may call multiple times)
4. `onDispose()` - Clean up resources (called once)

**Hook Points:**
- `main.toolbar` - Main toolbar
- `context_menu.node` - Node context menu
- `context_menu.graph` - Graph context menu
- `sidebar.top` - Sidebar top
- `sidebar.bottom` - Sidebar bottom
- `status.bar` - Status bar
- `settings` - Settings page
- Custom hook points can be registered dynamically

**Plugin Types:**
- **Service Plugins** - Provide business logic services and command handlers
- **UI Hook Plugins** - Extend UI at specific hook points via UIHookBase
- **Middleware Plugins** - Intercept and process commands in the Command Bus pipeline

**Important:** UI Hooks no longer extend Plugin. Use UIHookBase for UI extensions.

**Plugin Lifecycle:**
1. **Registration** - Plugin factory registered to PluginDiscoverer
2. **Discovery** - PluginDiscoverer instantiates plugin and reads metadata
3. **Dependency Resolution** - DependencyResolver determines load order
4. **Loading** - PluginManager.loadPlugin() calls plugin.onLoad(context)
5. **Enabling** - PluginManager.enablePlugin() calls plugin.onEnable()
6. **Disabling** - PluginManager.disablePlugin() calls plugin.onDisable()
7. **Unloading** - PluginManager.unloadPlugin() calls plugin.onUnload()

**Plugin Loading Order:**
- Plugins are loaded according to dependency relationships (topological sort)
- Depended plugins are loaded before dependent plugins
- Built-in plugins are loaded via `BuiltinPluginLoader` at app startup
- Plugin loading completes before app UI is displayed

**Key Plugin Files:**
- `lib/core/plugin/plugin.dart` - Base Plugin interface and lifecycle
- `lib/core/plugin/plugin_manager.dart` - Plugin lifecycle management
- `lib/core/plugin/plugin_discoverer.dart` - Plugin discovery and instantiation
- `lib/core/plugin/dependency_resolver.dart` - Dependency resolution
- `lib/core/plugin/builtin_plugin_loader.dart` - Built-in plugin loader
- `lib/core/plugin/ui_hooks/hook_base.dart` - UIHookBase interface (NEW)
- `lib/core/plugin/ui_hooks/hook_registry.dart` - Hook registry and lifecycle management
- `lib/core/plugin/ui_hooks/hook_point_registry.dart` - Hook point definitions (NEW)
- `lib/core/plugin/ui_hooks/hook_api_registry.dart` - Inter-hook API communication (NEW)
- `lib/core/plugin/ui_hooks/hook_metadata.dart` - Hook metadata (NEW)
- `lib/core/plugin/ui_hooks/hook_priority.dart` - Semantic priority levels (NEW)
- `lib/core/plugin/ui_hooks/hook_context.dart` - Hook context classes
- `lib/core/plugin/ui_hooks/hook_lifecycle.dart` - Hook lifecycle management (NEW)
- `lib/plugins/` - Built-in plugin implementations

**Unified Dependency Injection (DI) System**

The application now features a **unified DI container** that resolves the previous architecture problem of having multiple parallel DI systems:

**Problem Solved:**
- Previously had 4 parallel DI systems: Provider, ServiceRegistry, CommandContext, DependencyContainer
- PluginContext couldn't resolve services registered by the same plugin
- Provider tree was static but plugins needed dynamic loading
- Memory leaks from plugin services not being disposed

**Solution: ServiceRegistry + DynamicProviderWidget**

**ServiceRegistry** (`lib/core/plugin/service_registry.dart`):
- Enhanced ServiceRegistry with immediate service instantiation
- Supports lazy loading for non-critical services
- Provides `getServiceDirect<T>()` to bypass Provider
- Notifies listeners when services change (triggers Provider tree rebuild)
- Fully backward compatible with existing ServiceRegistry

**DynamicProviderWidget** (`lib/core/plugin/dynamic_provider_widget.dart`):
- Stateful widget that listens to ServiceRegistry changes
- Automatically rebuilds Provider tree when plugins load/unload
- Merges core providers and dynamic providers
- Maintains Provider tree integrity

**Usage Example:**

```dart
// 1. Create ServiceRegistry in app.dart
_serviceRegistry = ServiceRegistry(
  coreDependencies: {
    NodeRepository: _nodeRepository,
    GraphRepository: _graphRepository,
    CommandBus: _commandBus,
    AppEventBus: _eventBus,
  },
);

// 2. Use DynamicProviderWidget to wrap MultiProvider
DynamicProviderWidget(
  serviceRegistry: _serviceRegistry,
  coreProviders: [
    Provider<NodeRepository>.value(value: _nodeRepository),
    Provider<CommandBus>.value(value: _commandBus),
    // ... other core providers
  ],
  child: MaterialApp(...),
)

// 3. Plugins can now access their own services in onLoad()
class MyPlugin extends Plugin {
  @override
  List<ServiceBinding> registerServices() {
    return [
      MyServiceBinding(),
    ];
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    // This now works! PluginContext can resolve services
    // registered by the same plugin
    final myService = context.read<MyService>();
    myService.initialize();
  }
}
```

**Lazy Loading Support:**

```dart
class AIServiceBinding extends ServiceBinding<AIService> {
  @override
  bool get isLazy => true; // Only instantiate when first requested

  @override
  AIService createService(ServiceResolver resolver) {
    return AIServiceImpl(
      settingsService: resolver.get<SettingsService>(),
    );
  }
}
```

**Benefits:**
- Single source of truth for all dependencies
- Plugins can access their own services during initialization
- Dynamic plugin loading without breaking Provider tree
- Automatic memory management (services disposed on plugin unload)
- Performance optimization through lazy loading
- Zero breaking changes (fully backward compatible)

**Deprecated Components:**
- `DependencyContainer` - Marked as @Deprecated, use ServiceRegistry instead

**Creating Plugins:**

**Important Architecture Change (2026-03-17):**

The UI Hook system has been significantly refactored:
- **Old system**: `UIHook` extended `Plugin` (caused inheritance confusion)
- **New system**: `UIHookBase` is independent (simpler lifecycle, better separation)

**Migration Details**: See `docs/ui_hook_migration_deprecations.md` for complete migration documentation.

**New Hook System (UIHookBase):**

```dart
// 1. Create Hook class (extends UIHookBase, NOT Plugin)
class MyToolbarHook extends MainToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'com.example.my_toolbar_hook',
    name: 'My Toolbar Hook',
    version: '1.0.0',
    description: 'My custom toolbar hook',
  );

  @override
  String get hookPointId => 'main.toolbar'; // String ID, not enum

  @override
  HookPriority get priority => HookPriority.high; // Semantic priority

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    // Return UI widget
    return IconButton(
      icon: Icon(Icons.my_icon),
      onPressed: () => _handleAction(context),
      tooltip: 'My Action',
    );
  }

  // Optional: Initialize hook (called once)
  @override
  Future<void> onInit(HookContext context) async {
    // Cache services for performance
    _commandBus = context.pluginContext?.read<CommandBus>();
  }

  // Optional: Enable hook (can be called multiple times)
  @override
  Future<void> onEnable() async {
    // Activate hook functionality
  }

  // Optional: Disable hook (can be called multiple times)
  @override
  Future<void> onDisable() async {
    // Deactivate hook functionality
  }

  // Optional: Export APIs for other hooks
  @override
  Map<String, dynamic> exportAPIs() => {
    'my_api': MyAPI(),
  };

  CommandBus? _commandBus;
}

// 2. Create Plugin class that provides the Hook
class MyPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.myPlugin',
    name: 'My Plugin',
    version: '1.0.0',
    dependencies: [],
  );

  @override
  List<HookFactory> registerHooks() => [
    () => MyToolbarHook(), // Register hooks here
  ];

  @override
  List<ServiceBinding> registerServices() => [
    MyServiceBinding(), // Register services here
  ];

  @override
  Future<void> onLoad(PluginContext context) async {
    // Initialize plugin
  }
}
```

**Hook Lifecycle (New System):**

1. `onInit(context)` - Called once when hook is registered
2. `onEnable()` - Called when hook is activated (may call multiple times)
3. `onDisable()` - Called when hook is deactivated (may call multiple times)
4. `onDispose()` - Called once when hook is destroyed

**Key Differences from Old System:**

- ✅ No longer extends `Plugin` (simpler inheritance)
- ✅ Hook points use string IDs (supports dynamic registration)
- ✅ Semantic priorities (HookPriority enum instead of magic numbers)
- ✅ Can export APIs for inter-hook communication
- ✅ Lifecycle automatically synced with parent Plugin

**Available Hook Base Classes:**

- `MainToolbarHookBase` - Main toolbar
- `NodeContextMenuHookBase` - Node context menu
- `GraphContextMenuHookBase` - Graph context menu
- `SidebarHookBase` - Sidebar (all positions)
- `SidebarBottomHookBase` - Sidebar bottom only
- `StatusBarHookBase` - Status bar
- `SettingsHookBase` - Settings page
- `UIHookBase` - Generic hook (extend for custom hook points)

**Plugin Best Practices:**
- Always define dependencies in metadata if your plugin relies on other plugins
- Use `PluginContext` for accessing system APIs (CommandBus, EventBus, Repositories)
- Implement proper cleanup in `onUnload()` to avoid memory leaks
- Export APIs via `exportAPIs()` for inter-plugin communication
- **For UI extensions**: Create UIHookBase subclasses, register via `registerHooks()`
- **For services**: Register via `registerServices()`, not in hooks
- **For business logic**: Use command handlers, not hooks

**Hook Development Guidelines:**
- Use `UIHookBase` for UI extensions (not Plugin)
- Cache services in `onInit()` for performance
- Use semantic priorities (`HookPriority.high`, etc.) instead of magic numbers
- Export APIs for other hooks to use via `exportAPIs()`
- Access other hooks' APIs via `context.getHookAPI<T>(hookId, apiName)`
- Keep business logic out of hooks - use CommandBus instead

### Data Persistence

- **Nodes**: Stored as Markdown files with JSON metadata in `data/nodes/`
- **Graphs**: JSON files defining node connections in `data/graphs/`
- **Settings**: SharedPreferences (async) for app configuration
- **Search Presets**: Stored in SharedPreferences via SearchPresetService

## Coding Standards

This project follows strict coding standards defined in `docs/coding_standards.md`. Key points:

### Type Annotations

- **Public APIs MUST have type annotations**
- Private methods may omit types for brevity
- Use `??` for null-aware operations

### Flutter/Flame Specific

**Use `const` constructors:**

```dart
const Padding(
  padding: EdgeInsets.all(16),
  child: Text('Hello'),
)
```

**Flame component lifecycle:**

```dart
class NodeComponent extends PositionComponent {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Initialize resources
  }

  @override
  void render(Canvas canvas) {
    // Cache Paint objects, don't allocate in render
  }

  @override
  void onRemove() {
    // Dispose resources
    super.onRemove();
  }
}
```

**Deprecated APIs to Avoid:**

- `withOpacity()` → use `withValues(alpha:)`
- `HasGameRef` → use `HasGameReference`
- Use `existsSync()` instead of `await exists()`

### Error Handling

- Use typed exceptions, not generic `Exception`
- Avoid catching generic `Exception` - catch specific types
- Implement proper error recovery (see `lib/app.dart:149-257`)

### Code Organization

- **Constructors first** - before any class members (lint: `sort_constructors_first`)
- One class per file
- Import order: Dart SDK → Flutter → Third-party → Project imports → Relative imports

### Documentation & Comments

**MANDATORY: All code must include complete comments explaining architectural intent**

- **Public APIs MUST have documentation comments** explaining purpose, parameters, and return values
- **Complex logic MUST include inline comments** explaining the "why" (not just the "what")
- **Architectural decisions MUST be documented** - explain why code is structured a certain way
- **Non-obvious implementations MUST be explained** - if you override existing comments or patterns, explain why

**Example:**

```dart
/// 处理 BLoC 状态变化
  void _onStateChanged(GraphState state) {
    // 注意：这里只做增量更新，不重新创建整个 world
    // 具体的更新逻辑在 GraphWorld 中通过订阅实现

    // === 相机缩放同步 ===
    // 说明：由于 GraphWorld 无法访问 Flame 相机实例，相机相关的状态
    // 同步（缩放、位置等）需要在 GraphGame 层处理。

    // ... 相机缩放逻辑代码
  }
```

**Why this matters:**
- Future maintainers (including yourself) need to understand architectural decisions
- Comments explaining "why" prevent accidental removal of important code
- Architectural intent is often lost without explicit documentation


## Code Analysis

### Third-Party Plugin Warnings

Some plugins (like `file_picker`) produce platform integration warnings. These are **not your code's problem**. Use the provided analyze scripts to filter them out:

```bash
bash scripts/analyze.sh    # Filters third-party warnings
```

### Common Lint Rules

- `sort_constructors_first` - Constructors must come before fields
- `unnecessary_await_in_return` - Don't use `await` in return statements
- `avoid_slow_async_io` - Use `existsSync()` instead of `await exists()`
- `avoid_print` - Use `debugPrint` instead
- `prefer_const_constructors` - Use `const` wherever possible
- `use_decorated_box` - Use `DecoratedBox` when Container only has decoration

## Testing

Tests are organized by layer and functionality in `test/` directory:

```
test/
├── bloc/             # BLoC unit tests
│   ├── graph/       # GraphBloc tests
│   ├── node/        # NodeBloc tests
│   └── ui/          # UIBloc tests
├── core/            # Core logic tests
│   ├── events/      # Event bus tests
│   ├── models/      # Model tests (Node, Graph, Connection, etc.)
│   ├── repositories/ # Repository tests
│   └── services/    # Service tests (NodeService, UndoManager, etc.)
├── ui/              # UI interaction tests
│   ├── cross_bloc_ui_update_test.dart
│   └── ui_responsive_update_test.dart
├── performance/     # Performance benchmarks
│   └── ui_update_performance_test.dart
└── widget/          # Widget tests
    ├── app_widget_test.dart
    ├── graph_view_ui_update_test.dart
    └── user_interaction_ui_update_test.dart
```

**Key Test Files:**
- `test_helpers.dart` - Common test utilities and mocks
- Mock files generated with `@GenerateMocks` annotation (e.g., `*.mocks.dart`)

**Running Tests:**
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/bloc/graph/graph_bloc_test.dart

# Run with coverage
flutter test --coverage
```

**Testing Guidelines:**
- Use Mockito for mocking dependencies
- Test BLoCs in isolation with mock services
- Test widget interactions with `WidgetTester`
- Performance tests measure UI update efficiency

### ⚠️ Testing Best Practices (Avoid Fake Tests)

Based on comprehensive test analysis, the project has identified critical testing anti-patterns to avoid:

#### What Are Fake Tests?

Fake tests are tests that avoid testing core software issues, instead extensively testing trivial edge cases that don't provide real value. They create a false sense of security with high coverage but low quality.

#### Common Anti-Patterns

**1. Over-testing Simple Data Models** ❌

```dart
// ❌ FAKE TEST: Testing simple property access
test('should return correct id', () {
  expect(user.id, '123');
});

test('should return correct name', () {
  expect(user.name, 'John');
});

// ✅ GOOD TEST: Testing business logic
test('should validate user age', () {
  expect(() => User(age: -1), throwsException);
});
```

**Examples to Avoid:**
- Testing simple getter/setter methods
- Testing code-generated methods (copyWith, toJson, fromJson)
- Testing trivial data structures
- Testing basic property assignment

**2. Over-testing UI Edge Cases** ❌

```dart
// ❌ FAKE TEST: Testing extreme edge cases
test('should handle null text', () { ... });
test('should handle empty text', () { ... });
test('should handle whitespace text', () { ... });
test('should handle very long text', () { ... });
test('should handle special characters', () { ... });

// ✅ GOOD TEST: Testing core user interactions
test('should submit form successfully', () { ... });
test('should show validation error', () { ... });
test('should navigate after successful submission', () { ... });
```

**Examples to Avoid:**
- Testing null/empty/whitespace values extensively
- Testing framework-provided functionality
- Testing extreme edge cases that rarely occur
- Testing widget rendering details

**3. Testing Framework Features** ❌

```dart
// ❌ FAKE TEST: Testing framework functionality
test('should call setState', () {
  widget.setState(() {});
  verify(() {}).called(1);
});

// ✅ GOOD TEST: Testing business behavior
test('should update state when user clicks button', () {
  widget.find(button).tap();
  expect(widget.state, expectedState);
});
```

#### Test Value Assessment

**High-Value Tests:**
- ✅ Test core business logic
- ✅ Test complex scenarios
- ✅ Test error handling and recovery
- ✅ Test performance and security
- ✅ Test actual user workflows

**Low-Value Tests (Fake Tests):**
- ❌ Test simple getter/setter methods
- ❌ Test code-generated methods
- ❌ Test trivial data structures
- ❌ Test extreme edge cases
- ❌ Test framework-provided functionality

#### Fake Test Detection Checklist

Before writing a test, ask yourself:
- [ ] Does this test verify core business logic?
- [ ] Does this test verify complex scenarios?
- [ ] Does this test verify error handling?
- [ ] Does this test verify actual user workflows?
- [ ] Will this test failure provide useful debugging information?
- [ ] Is this test easy to maintain?
- [ ] Does this test run in reasonable time?
- [ ] Does this test help prevent regressions?

If most answers are "NO", it's likely a fake test - don't write it.

#### Core Testing Priorities

**Priority 1: Core Functionality (Must Have)**
- Command Handlers (business logic)
- Repository operations (data persistence)
- ExecutionEngine (task execution)
- Plugin Manager (plugin lifecycle)

**Priority 2: Integration Scenarios (Should Have)**
- Command Bus + Middleware pipeline
- Plugin dependencies and communication
- Event-driven updates
- Error recovery flows

**Priority 3: UI Workflows (Nice to Have)**
- User interaction paths
- State transitions
- Navigation flows
- Form validation

**Priority 4: Edge Cases (Optional)**
- Null/empty handling (only if realistic)
- Error boundary cases (only if critical)
- Performance edge cases (only if measured)

#### Examples of Good Tests

**Command Handler Test:**
```dart
test('should create node and publish event', () async {
  // Arrange
  final command = CreateNodeCommand(title: 'Test', content: 'Content');
  
  // Act
  final result = await handler.execute(command, context);
  
  // Assert
  expect(result.isSuccess, true);
  expect(result.data.title, 'Test');
  verify(eventBus.publish(any)).called(1);
});
```

**Repository Integration Test:**
```dart
test('should save and load node with metadata', () async {
  // Arrange
  final node = Node(id: '1', title: 'Test', metadata: {'key': 'value'});
  
  // Act
  await repository.save(node);
  final loaded = await repository.load('1');
  
  // Assert
  expect(loaded, isNotNull);
  expect(loaded!.metadata['key'], 'value');
});
```

**Plugin Lifecycle Test:**
```dart
test('should load plugin with dependencies', () async {
  // Arrange
  final plugin = TestPlugin(dependencies: ['other_plugin']);
  
  // Act
  await pluginManager.loadPlugin('test_plugin');
  
  // Assert
  expect(pluginManager.getPlugin('test_plugin'), isNotNull);
  expect(pluginManager.getPlugin('other_plugin'), isNotNull);
});
```

#### Known Issues from Test Analysis

**ExecutionEngine Tests:**
- 5/10 core tests are skipped due to architecture issues
- Critical functionality (task execution, error handling) not tested
- **Action Required**: Fix isolate communication architecture and enable tests

**Handler Layer Tests:**
- CreateNodeHandler has no tests
- ConnectNodesHandler has no tests
- Most other handlers lack test coverage
- **Action Required**: Write tests for all command handlers

**Plugin Manager Tests:**
- Missing integration tests for plugin dependencies
- Missing tests for inter-plugin communication
- Missing tests for API export/import
- **Action Required**: Add integration tests for plugin system

#### Testing Anti-Patterns to Avoid

1. **Don't test trivial data models** - Focus on business logic
2. **Don't test UI edge cases extensively** - Focus on user workflows
3. **Don't test framework features** - Trust the framework
4. **Don't skip core functionality tests** - Prioritize critical paths
5. **Don't write tests for code-generated methods** - They're already tested

**Remember:** High test coverage ≠ high test quality. Focus on testing what matters, not what's easy to test.

## UI Hook System Architecture (Refactored 2026-03-17)

### Overview

The UI Hook system has undergone a major refactoring to improve separation of concerns and simplify development. The old system where `UIHook` extended `Plugin` has been replaced with a new `UIHookBase` system.

### Key Changes

**Old System (Deprecated):**
```dart
// ❌ Old system - no longer recommended
class MyHook extends UIHook {  // UIHook extended Plugin
  @override
  PluginMetadata get metadata => ...;

  @override
  HookPointId get hookPoint => HookPointId.mainToolbar;  // Enum

  @override
  int get priority => 100;  // Magic number

  @override
  Widget render(HookContext context) => ...;

  // Had to implement all Plugin lifecycle methods
  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}
```

**New System (Current):**
```dart
// ✅ New system - recommended
class MyHook extends MainToolbarHookBase {  // UIHookBase is independent
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'com.example.my_hook',
    name: 'My Hook',
    version: '1.0.0',
    description: 'My custom hook',
  );

  // No need to specify hookPointId - it's built into the base class

  @override
  HookPriority get priority => HookPriority.high;  // Semantic enum

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(...);

  // Optional lifecycle methods
  @override
  Future<void> onInit(HookContext context) async {
    // Cache services here
  }

  @override
  Map<String, dynamic> exportAPIs() => {
    'my_api': MyAPI(),
  };
}
```

### Architecture Benefits

**Separation of Concerns:**
- **Plugins** handle business logic, services, and command handlers
- **Hooks** handle UI rendering and user interaction only
- No more inheritance confusion

**Simplified Lifecycle:**
- Old: 6 Plugin lifecycle methods to implement
- New: 4 Hook lifecycle methods, all optional

**Dynamic Hook Points:**
- Old: Enum-based hook points (required code changes to add new points)
- New: String-based hook points (plugins can register custom hook points)

**Semantic Priorities:**
- Old: Magic numbers (0-1000), easy to cause conflicts
- New: Semantic enum (critical, high, medium, low, decorative)

**Inter-Hook Communication:**
- Old: UIHook couldn't export APIs
- New: Hooks can export APIs via `exportAPIs()` and access via `context.getHookAPI<T>()`

### Hook Lifecycle Comparison

| Old System (Plugin) | New System (UIHookBase) | Purpose |
|---------------------|------------------------|---------|
| `onLoad(context)` | `onInit(context)` | Initialize (called once) |
| `onEnable()` | `onEnable()` | Activate (may call multiple times) |
| `onDisable()` | `onDisable()` | Deactivate (may call multiple times) |
| `onUnload()` | `onDispose()` | Clean up (called once) |
| ~~(5 more methods)~~ | N/A | Removed - hooks don't need them |

### New Hook Point IDs

Hook points are now string-based instead of enum-based:

```dart
// Old enum-based (removed)
HookPointId.mainToolbar
HookPointId.sidebarTop

// New string-based
'main.toolbar'
'sidebar.top'
'context_menu.node'
'context_menu.graph'
'sidebar.bottom'
'status.bar'
'settings'
```

**Dynamic Registration:**
```dart
// Plugins can register custom hook points
hookRegistry.registerHookPoint(HookPointDefinition(
  id: 'my_custom.point',
  name: 'My Custom Hook Point',
  description: 'Custom extension point',
));
```

### Semantic Priorities

```dart
// Old: Magic numbers
@override
int get priority => 100;  // What does 100 mean?

// New: Semantic enum
@override
HookPriority get priority => HookPriority.high;  // Clear intent
```

**Priority Levels:**
- `critical (0)` - System critical features (save, undo/redo)
- `high (100)` - Important features (search, create)
- `medium (500)` - Standard features (default)
- `low (800)` - Optional features
- `decorative (1000)` - Decorative elements

### Inter-Hook API Communication

**Exporting APIs:**
```dart
class FormattingHook extends UIHookBase {
  @override
  Map<String, dynamic> exportAPIs() => {
    'formatting_api': TextFormattingAPI(),
    'validation_api': InputValidationAPI(),
  };
}
```

**Using Other Hooks' APIs:**
```dart
class MyHook extends UIHookBase {
  @override
  Widget render(HookContext context) {
    // Get another hook's API
    final formattingAPI = context.getHookAPI<TextFormattingAPI>(
      'com.example.formatting_hook',
      'formatting_api',
    );

    return TextButton(
      onPressed: () => formattingAPI?.formatText(selectedText),
      child: Text('Format'),
    );
  }
}
```

### Migration Guide

For detailed migration information, see:
- `docs/ui_hook_migration_deprecations.md` - Complete migration documentation
- `lib/core/plugin/ui_hooks/hook_base.dart` - UIHookBase interface
- `lib/plugins/*/` - Example implementations

### Quick Migration Checklist

To migrate from old UIHook to new UIHookBase:

1. Change parent class from `UIHook` to `UIHookBase` (or specific base class)
2. Update `metadata` to use `HookMetadata` instead of `PluginMetadata`
3. Replace `HookPointId` enum with string ID (or remove if using base class)
4. Replace `int priority` with `HookPriority` enum
5. Move service/command registration from Hook to Plugin
6. Update lifecycle methods:
   - `onLoad()` → `onInit()`
   - `onUnload()` → `onDispose()`
7. Add `exportAPIs()` if hook provides APIs for other hooks

---

## Important Notes

### Architecture Patterns

1. **CQRS Pattern**: Separate read (Repository) and write (CommandBus) operations
2. **Event-Driven**: Use EventBus for cross-component communication
3. **Plugin Architecture**: Extend functionality via plugins, not direct modifications
4. **Unified Dependency Injection**: Single DI container (ServiceRegistry) supporting both Provider and dynamic plugin loading

### Development Guidelines

5. **Always regenerate code** after modifying models with `@JsonSerializable` annotation
6. **Provider dependency order is critical**:
   - Settings/Theme → Repositories → EventBus → CommandBus → Plugin Services → Plugin BLoCs → Core BLoCs → Plugin System
7. **Don't use `print()`** - use `debugPrint()` or LoggingMiddleware
8. **File I/O should be async** - avoid blocking the UI thread with sync operations
9. **Flame performance** - cache Paint/Text objects, don't allocate in `render()` method
10. **Error recovery** - app has built-in data recovery on initialization failures

### Command Bus Usage

11. **Write operations** → Always use `CommandBus.dispatch(command)`
12. **Read operations** → Use `Repository` directly (don't go through CommandBus)
13. **Business logic** → Implement in Command Handlers, not in BLoCs or Services
14. **Event publishing** → Publish events in Command Handlers after data changes
15. **Undo support** → Implement `undo()` method in Command if operation should be undoable

### BLoC Best Practices

16. **BLoC responsibilities** → Only manage UI state (isLoading, error, selection)
17. **No business logic in BLoCs** → Delegate to CommandBus
18. **Subscribe to EventBus** → React to data changes from other components
19. **Initial events** → Always add initial events when creating BLoCs
20. **State updates** → Update state based on CommandResult, not directly

### Plugin Development

21. **Plugin location** → Create plugins in `lib/plugins/{plugin_name}/`
22. **Plugin dependencies** → Always declare in metadata to ensure correct load order
23. **Plugin lifecycle** → Use `onLoad()` for initialization, `onEnable()` for activation
24. **Service registration** → Use `registerServices()` to provide plugin services
25. **Command handlers** → Register via `registerCommandHandlers()` method
26. **UI Hooks** → Extend UI at specific hook points via HookRegistry
27. **API exports** → Export APIs via `exportAPIs()` for inter-plugin communication

### Testing Considerations

32. **Test isolation** → Mock CommandBus, Repository, and EventBus
33. **Test Command Handlers** → Test business logic in isolation
34. **Test BLoCs** → Test state management, not business logic
35. **Integration tests** → Test full command flow from UI to Repository
36. **Avoid fake tests** → Focus on core business logic, not trivial edge cases
37. **Test priority** → Core functionality > Integration > UI workflows > Edge cases
38. **Test value assessment** → Use fake test detection checklist before writing tests
