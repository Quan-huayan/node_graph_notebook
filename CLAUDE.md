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

1. Create command class in `lib/plugins/builtin_plugins/{plugin_name}/command/`
2. Create handler in `lib/plugins/builtin_plugins/{plugin_name}/handler/`
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
- `lib/plugins/builtin_plugins/` - Built-in plugin implementations

**Middleware:**
- `lib/plugins/builtin_middlewares/logging_middleware.dart`
- `lib/plugins/builtin_middlewares/validation_middleware.dart`
- `lib/plugins/builtin_middlewares/transaction_middleware.dart`
- `lib/plugins/builtin_middlewares/undo_middleware.dart`

**BLoC Examples:**
- `lib/plugins/builtin_plugins/graph/bloc/node_bloc.dart` - Refactored NodeBloc

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
   - Hook points: toolbar, sidebar, context menus, dialogs, etc.

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

- **Plugin-Provided BLoCs** (`lib/plugins/builtin_plugins/{plugin}/bloc/`):
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
- Commands: `lib/plugins/builtin_plugins/{plugin}/command/`
- Handlers: `lib/plugins/builtin_plugins/{plugin}/handler/`
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

**Plugin-Based Services** (`lib/plugins/builtin_plugins/`)

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
- **Hook Registry** - Manages UI hooks for extending application UI

**Plugin Types:**
- **UI Hook Plugins** - Extend UI at specific hook points (toolbar, sidebar, context menus, etc.)
- **Service Plugins** - Provide additional services and functionality
- **Middleware Plugins** - Intercept and process commands in the Command Bus pipeline

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
- `lib/core/plugin/ui_hooks/` - UI Hook system
- `lib/plugins/builtin_plugins/` - Built-in plugin implementations

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

```dart
// 1. Create plugin class
class MyPlugin extends UIHook {
  @override
  PluginMetadata get metadata => PluginMetadata(
    id: 'com.example.myPlugin',
    name: 'My Plugin',
    version: '1.0.0',
    dependencies: [], // List of plugin IDs this plugin depends on
  );

  @override
  HookPointId get hookPoint => HookPointId.mainToolbar;

  @override
  int get priority => 100; // Lower = higher priority

  @override
  Widget render(HookContext context) {
    // Return UI widget
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    // Initialize plugin
  }

  @override
  Future<void> onEnable() async {
    // Activate plugin functionality
  }

  @override
  Future<void> onDisable() async {
    // Deactivate plugin functionality
  }

  @override
  Future<void> onUnload() async {
    // Clean up resources
  }
}

// 2. Register plugin factory in BuiltinPluginLoader
final List<UIHookFactory> _builtinUIHookFactories = [
  // ... other plugins
  () => MyPlugin(), // Add your plugin here
];
```

**Plugin Best Practices:**
- Always define dependencies in metadata if your plugin relies on other plugins
- Use `PluginContext` for accessing system APIs (CommandBus, EventBus, Repositories)
- Implement proper cleanup in `onUnload()` to avoid memory leaks
- Use priority to control UI element order when multiple plugins hook to same point
- Export APIs via `exportAPIs()` for inter-plugin communication

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

21. **Plugin location** → Create plugins in `lib/plugins/builtin_plugins/{plugin_name}/`
22. **Plugin dependencies** → Always declare in metadata to ensure correct load order
23. **Plugin lifecycle** → Use `onLoad()` for initialization, `onEnable()` for activation
24. **Service registration** → Use `registerServices()` to provide plugin services
25. **Command handlers** → Register via `registerCommandHandlers()` method
26. **UI Hooks** → Extend UI at specific hook points via HookRegistry
27. **API exports** → Export APIs via `exportAPIs()` for inter-plugin communication

### Testing Considerations

28. **Test isolation** → Mock CommandBus, Repository, and EventBus
29. **Test Command Handlers** → Test business logic in isolation
30. **Test BLoCs** → Test state management, not business logic
31. **Integration tests** → Test full command flow from UI to Repository
