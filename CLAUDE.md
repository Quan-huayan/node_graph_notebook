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

## ⚠️ Active Refactoring

**The project is currently undergoing a major architectural refactoring. Please read the refactoring documentation before making significant changes.**

### Current Phase: Phase 1 - Command Bus Implementation

The project is implementing a Command Bus pattern to improve separation of concerns and testability. This refactoring introduces:

- **Command Bus**: Centralized business logic execution
- **CQRS Pattern**: Separate read (Repository) and write (Command) operations
- **Middleware Pipeline**: Cross-cutting concerns (logging, validation, transactions)
- **BLoC Restructuring**: BLoCs now only manage UI state, not business logic

### Important Documentation

**Before making changes, read:**
- [Refactoring README](docs/refactor/README.md) - Overview of refactoring process
- [Phase 1 Plan](docs/refactor/phase_1_command_bus/refactor_plan.md) - Detailed plan for current phase
- [Phase 1 Status](docs/refactor/phase_1_command_bus/refactor_status.md) - Current implementation status
- [Phase 1 Changes](docs/refactor/phase_1_command_bus/refactor_changes.md) - Detailed architecture changes

### Key Architecture Changes

**New Architecture:**
```
UI → BLoC → CommandBus → Handlers → Service/Repository
     (UI State)   (Business Logic)
```

**Important:**
- ✅ **Write operations** (create, update, delete) → Use `CommandBus.dispatch()`
- ✅ **Read operations** (load, search) → Use `Repository` directly
- ✅ **BLoCs** → Only manage UI state (isLoading, error, selection)
- ✅ **EventBus** → Subscribe to data changes from other BLoCs

### Implementation Status

Phase 1 is approximately **85% complete**:
- ✅ Core Command Bus infrastructure
- ✅ Node commands and handlers (7 commands)
- ✅ Middleware system (3 middleware)
- ✅ NodeBloc refactored
- ⏳ API alignment issues (some compilation errors)
- ⏳ Tests not yet written

**Current blockers:**
- API alignment between handlers and existing services
- Missing EventBus integration in CommandContext
- Compilation errors need fixing before testing

### How to Work with the New Architecture

#### Adding New Commands

1. Create command class in `lib/core/commands/impl/`
2. Create handler in `lib/core/commands/handlers/`
3. Register handler in `lib/app.dart`
4. Use in BLoC via `commandBus.dispatch(command)`

#### Adding New Middleware

1. Create middleware class in `lib/core/commands/middleware/`
2. Register in `lib/app.dart` with `commandBus.addMiddleware()`

#### Modifying BLoCs

- Write operations → Use `CommandBus`
- Read operations → Use `Repository` directly
- Subscribe to `EventBus` for data changes
- Do NOT include business logic in BLoC

### Related Files

**New Command Bus Files:**
- `lib/core/commands/command.dart`
- `lib/core/commands/command_bus.dart`
- `lib/core/commands/command_context.dart`
- `lib/core/commands/impl/node_commands.dart`
- `lib/core/commands/handlers/*.dart`
- `lib/core/commands/middleware/*.dart`

**Modified Files:**
- `lib/app.dart` - Added CommandBus provider
- `lib/bloc/node/node_bloc.dart` - Refactored to use CommandBus

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

The application initializes dependencies in layers using Provider:

```dart
// 0. Settings & Theme Services
ChangeNotifierProvider<SettingsService>,
ChangeNotifierProvider<ThemeService>,
Provider<SharedPreferencesAsync>,

// 1. Repository Layer
Provider<NodeRepository>,
Provider<GraphRepository>,

// 2. Service Layer
Provider<NodeService>,
Provider<GraphService>,
Provider<SearchPresetService>,
Provider<ConverterService>,
Provider<ImportExportService>,
ChangeNotifierProvider<AIServiceImpl>,
Provider<LayoutService>,

// 3. Event Bus & Command Bus
Provider<AppEventBus>,
Provider<CommandBus>,

// 4. Command Handler Registration (via ProxyProvider)
// - Registers Node, Graph, Layout, and AI command handlers

// 5. BLoC Layer
BlocProvider<NodeBloc>,
BlocProvider<GraphBloc>,
BlocProvider<UIBloc>,
BlocProvider<SearchBloc>,
BlocProvider<ConverterBloc>,

// 6. Plugin System (loaded synchronously before UI)
Provider<HookRegistry>,
Provider<PluginManager>,
```

**Plugin Loading:**
- Built-in plugins are loaded via `FutureBuilder` before app UI displays
- `BuiltinPluginLoader` registers plugin factories to `PluginDiscoverer`
- `DependencyResolver` determines load order based on dependencies
- Plugins are loaded through `PluginManager` in dependency order
- UI Hook plugins are registered to `HookRegistry` after loading
- App shows "Loading plugins..." screen during plugin initialization

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

The application uses **BLoC (Business Logic Component)** pattern for state management, organized by domain:

**BLoC Structure** (`lib/bloc/`):

- `NodeBloc` - Manages node state (CRUD operations, loading)
- `GraphBloc` - Manages graph state and node relationships
- `UIBloc` - Manages UI state (sidebar, panels, dialogs)
- `SearchBloc` - Manages search functionality and presets
- `ConverterBloc` - Manages import/export operations

**Event Bus Pattern** (`lib/core/events/app_events.dart`):

The `AppEventBus` enables **cross-BLoC communication** without direct dependencies:

```dart
// Singleton event bus for pub-sub communication
final eventBus = AppEventBus();

// NodeBloc publishes node changes
eventBus.publish(NodeDataChangedEvent(
  changedNodes: nodes,
  action: DataChangeAction.update,
));

// GraphBloc subscribes to node changes
eventBus.stream.listen((event) {
  if (event is NodeDataChangedEvent) {
    // Update graph visualization
  }
});
```

**Key Benefits:**
- **Decoupling**: NodeBloc and GraphBloc communicate without direct dependencies
- **Scalability**: Easy to add new BLoCs that subscribe to events
- **Testability**: Each BLoC can be tested independently

**Event Types:**
- `NodeDataChangedEvent` - Published when nodes are created/updated/deleted
- `GraphNodeRelationChangedEvent` - Published when node-graph relationships change

**4. Command Pattern (Undo/Redo)**

The UndoManager uses the Command pattern for undoable operations:

```dart
// Define a command
class AddNodeCommand extends Command {
  final Node node;
  AddNodeCommand(this.node);

  @override
  Future<void> execute() async {
    // Add node logic
  }

  @override
  Future<void> undo() async {
    // Remove node logic
  }
}

// Execute with undo support
await context.read<UndoManager>().execute(AddNodeCommand(newNode));

// Undo last operation
await context.read<UndoManager>().undo();
```

**Command Locations:**
- `lib/core/services/commands/command.dart` - Base Command interface
- `lib/core/services/commands/node_commands.dart` - Node-related commands
- `lib/core/services/commands/graph_command.dart` - Graph-related commands

**Usage Guidelines:**
- Implement `execute()` and `undo()` methods for all commands
- Commands should be idempotent (can be executed multiple times safely)
- UndoManager maintains a stack of up to 50 commands
- Commands are automatically added to the undo stack when executed

### Core Components

**Data Layer** (`lib/core/`)

- `models/` - Core data models (Node, Graph, NodeReference, Connection, etc.)
  - `Connection` - Defines relationships between nodes (computed from NodeReference)
- `repositories/` - File-based data persistence (FileSystemNodeRepository, FileSystemGraphRepository)
  - `MetadataIndex` - Efficient node metadata indexing for fast lookups
- `services/` - Business logic services:
  - `NodeService` - Node CRUD operations
  - `GraphService` - Graph management operations
  - `SearchPresetService` - Saved search configurations
  - `ConverterService` - Format conversion (internal ↔ external formats)
  - `ImportExportService` - Data import/export functionality
  - `UndoManager` - Command pattern for undo/redo operations
  - `LayoutService` - Graph layout algorithms
  - `DataRecoveryService` - Automatic data repair on corruption
  - `AIIntegrationService` - AI service integration layer
  - `SettingsService` - App configuration management
  - `ThemeService` - Theme customization
- `events/` - Event bus system for cross-BLoC communication
  - `AppEventBus` - Singleton broadcast stream for decoupled communication

**Converter Layer** (`lib/converter/`)

- `ConverterService` - Converts between internal node format and external formats
- Supports markdown with YAML frontmatter for round-trip editing

**BLoC Layer** (`lib/bloc/`)

- Domain-specific BLoCs for state management
- Each BLoC has corresponding Event and State classes
- Uses flutter_bloc library for BLoC implementation

**UI Layer** (`lib/ui/`)

- `models/` - State management models (NodeModel, GraphModel, UIModel)
- `pages/` - Full-screen pages
- `widgets/` - Reusable components
- `dialogs/` - Dialogs and modals
- `views/` - View widgets (graph view, folder tree, etc.)

**Visualization** (`lib/flame/`)

- Flame engine components for interactive node graphs
- Custom rendering and interaction handling

**AI Integration** (`lib/ai/`)

- `AIServiceImpl` - Main AI service implementation
- Supports OpenAI and Anthropic providers
- Requires API keys configuration

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

1. **Always regenerate code** after modifying models with `@JsonSerializable` annotation
2. **Provider/BLoC dependency order matters** - repositories → services → event bus → command bus → BLoCs → plugins
3. **Don't use `print()`** - use `debugPrint()` or a logging service
4. **File I/O should be async** - avoid blocking the UI thread with sync operations
5. **Flame performance** - cache Paint/Text objects, don't allocate in `render()` method
6. **Error recovery** - app has built-in data recovery on initialization failures
7. **BLoC event handling** - always add initial events when creating BLoCs (e.g., `..add(const NodeLoadEvent())`)
8. **Event bus usage** - use AppEventBus for cross-BLoC communication, avoid direct BLoC-to-BLoC dependencies
9. **Command pattern** - use CommandBus for write operations (define commands in `lib/plugins/builtin_plugins/*/command/`)
10. **SharedPreferences async** - use `SharedPreferencesAsync` for non-blocking preference access
11. **Plugin loading** - plugins are loaded synchronously at app startup in dependency order
12. **Plugin dependencies** - always declare plugin dependencies in metadata to ensure correct load order
13. **Plugin lifecycle** - use `onLoad()` for initialization, `onEnable()` for activation
14. **UI Hooks** - register UI Hook plugins to HookRegistry to extend UI at specific points
