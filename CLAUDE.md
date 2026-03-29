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
- Lua scripting support for automation
- Internationalization (i18n) support

## Architecture Status

**Implementation Complete (95%)**

The refactoring has successfully introduced:
- **Command Bus**: Centralized business logic execution with middleware pipeline and integrated event publishing
- **CQRS Pattern**: Complete separation of read (Query Bus) and write (Command) operations with query caching
- **Plugin System**: Fully functional plugin architecture with UI hooks, service providers, and middleware plugins
- **BLoC Restructuring**: BLoCs now only manage UI state, all business logic in Command Handlers
- **Event-Driven Architecture**: CommandBus.eventStream as primary event source, AppEventBus for legacy support
- **Unified DI Container**: Single dependency injection system supporting both Provider and dynamic plugin loading
- **Lua Scripting**: Complete Lua integration for dynamic UI hooks and automation
- **UI Layout System**: Flexible layout management with multiple rendering backends (Flame/Flutter)
- **Execution Engine**: CPU/GPU task separation for performance optimization
- **Graph Data Structures**: Advanced spatial indexing and graph partitioning

**Known Issues:** (See current commit messages and git history for details)
- Minor inconsistencies in Repository access patterns (some BLoCs access Repository directly vs QueryBus)
- Event system dual implementation (CommandBus.eventStream vs AppEventBus) - migration in progress
- Some middleware implementations incomplete (performance monitoring, caching)

## Architecture Pattern

```
UI Layer (Widgets)
    ↓
BLoC Layer (UI State Management)
    ↓
CommandBus/QueryBus (Business Logic Gateway)
    ↓
Command/Query Handlers (Business Logic)
    ↓
Services/Repositories (Data Access)
```

**Important Patterns:**
- ✅ **Write operations** → Use `CommandBus.dispatch(command)` (automatically publishes events)
- ✅ **Read operations** → Use `QueryBus.dispatch(query)` for complex queries with caching, or Repository directly for simple queries
- ✅ **BLoCs** → Only manage UI state (isLoading, error, selection)
- ✅ **Event subscription** → Subscribe to `CommandBus.eventStream` for data changes (primary), or `AppEventBus` for legacy events
- ✅ **Plugins** → Extend functionality via hooks, services, and middleware

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

**Before Running:** After pulling changes or modifying models in `lib/core/models/`, always run:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Project Structure

### Core Components (`lib/core/`)

**Models** (`models/`):
- `node.dart` - Base class for all content elements with metadata support
- `graph.dart` - Manages node connections and relationships
- `connection.dart` - Defines relationships between nodes
- `node_reference.dart` - Reference objects for node relationships
- `node_rendering.dart` - Rendering-specific models for node visualization
- `enums.dart` - Core enumerations used across the application
- `converters.dart` - JSON serialization converters

**Repositories** (`repositories/`):
- `node_repository.dart` - Node storage as Markdown files
- `graph_repository.dart` - Graph storage as JSON files
- `metadata_index.dart` - Fast metadata indexing system
- `exceptions.dart` - Repository-specific exceptions

**Command System** (`commands/`):
- `command_bus.dart` - Central command dispatcher with middleware pipeline and integrated event publishing
- `models/command.dart` - Command base classes with undo support
- `models/command_context.dart` - Context for command execution
- `models/command_handler.dart` - Handler interface for commands
- `models/middleware.dart` - Middleware interfaces
- `command_handler_registry.dart` - Handler registration and lookup

**CQRS System** (`cqrs/`):
- `query/query_bus.dart` - Query dispatcher for read operations with LRU caching
- `query/query.dart` - Query base classes and interfaces
- `query/query_cache.dart` - LRU cache implementation (1000 entries)
- `queries/` - Query definitions:
  - `search_nodes_query.dart` - Node search queries
  - `list_nodes_query.dart` - Node listing queries
  - `load_node_query.dart` - Single node loading
  - `graph_query.dart` - Graph structure queries
  - `search_index_query.dart` - Search index queries
- `handlers/` - Query handlers for read operations
- `read_models/` - Read-optimized data models:
  - `node_read_model.dart` - Denormalized node data for queries
- `materialized_views/` - Pre-computed views for performance:
  - `search_index_view.dart` - Materialized search index

**Plugin System** (`plugin/`):
- `plugin.dart` / `plugin_base.dart` - Base Plugin interface and lifecycle
- `plugin_manager.dart` - Plugin lifecycle management
- `plugin_context.dart` - Context for plugin operations
- `plugin_metadata.dart` - Plugin metadata definitions
- `plugin_lifecycle.dart` - Lifecycle state management
- `plugin_registry.dart` - Plugin registration and discovery
- `plugin_discoverer.dart` - Automatic plugin discovery
- `plugin_communication.dart` - Inter-plugin communication
- `plugin_exception.dart` - Plugin-specific exceptions
- `builtin_plugin_loader.dart` - Built-in plugin loading
- `service_binding.dart` - Service registration bindings
- `service_registry.dart` - Unified dependency injection container
- `dependency_resolver.dart` - Plugin dependency resolution
- `dynamic_provider_widget.dart` - Dynamic provider tree management
- `ui_hooks/` - UI Hook system for extending UI:
  - `hook_base.dart` - Base hook interface
  - `hook_lifecycle.dart` - Hook lifecycle management
  - `hook_registry.dart` - Hook point registry
  - `hook_point_registry.dart` - String-based hook point management
  - `hook_metadata.dart` - Hook metadata definitions
  - `hook_context.dart` - Context for hook execution
  - `hook_priority.dart` - Semantic priority levels
  - `hook_api_registry.dart` - Hook API registry
  - `sidebar_tab_hook_base.dart` - Specialized sidebar tab hooks
- `middleware/` - Plugin middleware support:
  - `middleware_plugin.dart` - Middleware as plugins
  - `middleware_pipeline.dart` - Middleware pipeline execution
  - `middleware_registry.dart` - Middleware registration
- `api/` - API registry for inter-plugin communication:
  - `api_registry.dart` - API registration and lookup

**Event System** (`events/`):
- `app_events.dart` - Application event definitions (NodeDataChangedEvent, etc.)
- `event_subscription_manager.dart` - Event subscription lifecycle management
- **CommandBus.eventStream** - **Primary** event source (integrated into CommandBus)
- **AppEventBus** - Legacy event bus (being phased out, use CommandBus.eventStream for new code)

**Middleware** (`middleware/`):
- `logging_middleware.dart` - Command execution logging
- `validation_middleware.dart` - Command validation
- `transaction_middleware.dart` - Transaction support
- `undo_middleware.dart` - Undo/redo functionality
- `performance_middleware.dart` - Performance monitoring
- `cache_middleware.dart` - Caching layer

**Services** (`services/`):
- `services.dart` - Services barrel file
- `settings_service.dart` - Application settings management
- `theme_service.dart` - Theme management and switching
- `data_recovery_service.dart` - Data backup and recovery
- `shortcut_manager.dart` - Keyboard shortcut management
- `i18n.dart` - Internationalization service
- `infrastructure/` - Infrastructure services:
  - `settings_registry.dart` - Settings registration
  - `theme_registry.dart` - Theme registration
  - `storage_path_service.dart` - Storage path management
- `i18n/` - Internationalization:
  - `translations.dart` - Translation management

**UI Layout System** (`ui_layout/`):
- `ui_layout_service.dart` - Central layout management service
- `coordinate_system.dart` - Coordinate system management
- `layout_strategy.dart` - Layout algorithm strategies
- `node_template.dart` - Node rendering templates
- `node_attachment.dart` - Node attachment system
- `ui_hook_tree.dart` - UI hook tree structure
- `rendering/` - Multiple rendering backends:
  - `renderer_base.dart` - Base renderer interface
  - `flame_renderer.dart` - Flame game engine renderer
  - `flutter_renderer.dart` - Flutter native renderer
- `events/` - Layout-specific events:
  - `layout_events.dart` - Layout change events

**Graph Data Structures** (`graph/`):
- `adjacency_list.dart` - Graph adjacency list implementation
- `partition/` - Graph partitioning:
  - `graph_partitioner.dart` - Graph partitioning algorithms
  - `subgraph_cache.dart` - Subgraph caching
- `spatial/` - Spatial indexing:
  - `quad_tree.dart` - QuadTree spatial index

**Execution System** (`execution/`):
- `execution_engine.dart` - CPU/GPU task execution engine
- `task_registry.dart` - Task registration and management
- `cpu_task.dart` - CPU task implementation
- `gpu_executor.dart` - GPU task executor

**Concurrency** (`concurrency/`):
- `automatic_batching_middleware.dart` - Automatic command batching
- `event_aggregation_middleware.dart` - Event aggregation for performance

**Metadata** (`metadata/`):
- `metadata_validator.dart` - Metadata validation
- `metadata_schema.dart` - Metadata schema definitions
- `standard_metadata.dart` - Standard metadata types

**Configuration** (`config/`):
- `feature_flags.dart` - Feature flag management

**Utilities** (`utils/`):
- `logger.dart` - Logging utilities
- `yaml_utils.dart` - YAML processing utilities

### Plugin Architecture (`lib/plugins/`)

**Plugin Structure:**
Plugins are organized as self-contained modules in `lib/plugins/{plugin_name}/`:

```
{plugin_name}/
├── command/        # Command definitions (optional)
├── handler/        # Command handlers (optional)
├── service/        # Business logic services (optional)
├── bloc/           # State management BLoCs (optional)
├── ui/             # UI components (optional)
├── models/         # Plugin-specific models (optional)
├── {plugin_name}_plugin.dart  # Main plugin file
└── *_hook.dart     # UI hook registrations (optional)
```

**Available Plugins:**
- `graph/` - Core node and graph management with Flame integration
- `ai/` - AI integration features (chat, analysis)
- `editor/` - Text editing with Markdown support
- `search/` - Node search functionality with presets
- `layout/` - Graph layout algorithms
- `converter/` - Import/export functionality (Markdown, JSON)
- `settings/` - Application settings management
- `folder/` - Folder tree view sidebar
- `lua/` - Lua scripting engine and automation
- `i18n/` - Internationalization support
- `market/` - Plugin marketplace UI
- `data_recovery/` - Data backup and repair tools
- `delete/` - Node deletion functionality
- `sidebarNode/` - Sidebar node list view

### UI Layer (`lib/ui/`)

The UI layer follows Flutter best practices with clear separation between presentation, state management, and business logic.

**Core UI State Management (`bloc/`):**
- `ui_bloc.dart` - Central UI state management (node view modes, connections, sidebar, toolbar)
- `ui_event.dart` - UI events for state changes
- `ui_state.dart` - UI state definitions

**Application Bars (`bars/`):**
- `core_toolbar.dart` - Main application toolbar with hook system integration
- `note_app_bar.dart` - Note-specific app bar
- `sidebar.dart` - Application sidebar

**Pages (`pages/`):**
- `home_page.dart` - Main application page
- `plugin_market_page.dart` - Plugin marketplace page

**Dialogs (`dialogs/`):**
- `settings_dialog.dart` - Application settings dialog
- `shortcut_help_dialog.dart` - Keyboard shortcuts help dialog

**Widgets (`widgets/` & `utilwidgets/`):**
- `plugin_item.dart` - Plugin list item widget
- `highlight_text.dart` - Text highlighting utility

**UI Patterns:**
- **Hook-Based UI System**: Dynamic hook system for plugin extensibility
- **BLoC State Management**: Single UIBloc manages global UI state
- **Responsive Layout**: Dynamic sidebar and conditional rendering
- **Feature Flags**: Conditional UI component enabling

### Visualization (`lib/plugins/graph/flame/`)

Flame engine components for interactive node graphs with performance optimization:

**Core Components:**
- `graph_widget.dart` - Main Flame game widget integrating with BLoC
- `graph_world.dart` - Root Flame component managing the entire graph visualization
- `flame.dart` - Library exports module

**Rendering Components (`components/`):**
- `node_component.dart` - Individual node rendering component with:
  - Multiple node types (regular, folder, AI nodes)
  - View modes (titleOnly, compact, titleWithPreview, fullContent)
  - Drag-and-drop functionality
  - Click, double-click, right-click interactions
  - Custom icons and reference count badges
  - Different rendering shapes (rectangles, circles, folder tabs)
- `connection_renderer.dart` - Connection line rendering with:
  - Multiple line styles (solid, dashed, dotted)
  - Directional arrows
  - Connection labels (roles)
  - Dynamic updates on node movement

**Performance Optimization:**
- `spatial_index_manager.dart` - QuadTree-based spatial indexing for O(log n) queries
- `lod/` - Level-of-detail rendering:
  - `lod_manager.dart` - Adjusts rendering detail based on distance
- `view_frustum_culler.dart` - View frustum culling for visible nodes only

**Integration:**
- `mixins/bloc_consumer.dart` - BLoC integration for Flame components

### Data Persistence

- **Nodes**: Markdown files with YAML frontmatter in `data/nodes/`
- **Graphs**: JSON files defining node connections in `data/graphs/`
- **Settings**: SharedPreferences for app configuration
- **Lua Scripts**: Stored in `data/lua_scripts/` and `data/scripts/`
- **Search Presets**: Stored in SharedPreferences via SearchPresetService

## Dependency Injection Order

The application initializes dependencies in strict layers using **DynamicProviderWidget**:

1. **ServiceRegistry** - Core DI container and infrastructure
2. **Core Services** - Settings, Theme, Storage paths, I18n
3. **Repositories** - NodeRepository, GraphRepository, MetadataIndex
4. **EventBus** - Event publication infrastructure (AppEventBus legacy)
5. **CommandBus** - Command dispatcher with middleware and eventStream integration
6. **QueryBus** - Query dispatcher with caching support
7. **UI Layout Service** - Central layout management
8. **Execution Engine** - Task execution system
9. **Core UI BLoC** - Global UI state management
10. **Plugin System** - HookRegistry and PluginManager
11. **Plugin Services** - Plugin-specific service registration
12. **Plugin BLoCs** - Plugin-specific UI state management

**Key Points:**
- ServiceRegistry provides unified dependency injection
- Plugins can register services that participate in DI
- Provider tree rebuilds dynamically when plugins load/unload
- Plugins access their services via PluginContext in `onLoad()`
- CommandBus.eventStream is the primary event source (integrated)
- AppEventBus exists for legacy support (being phased out)

## BLoC Pattern

**BLoC Responsibilities (After Refactoring):**

```dart
// ✅ CORRECT: BLoC manages UI state only
class NodeBloc extends Bloc<NodeEvent, NodeState> {
  Future<void> _onCreateNode(NodeCreateEvent event, Emitter emit) async {
    emit(state.copyWith(isLoading: true));

    // Write operations go through CommandBus
    final result = await _commandBus.dispatch(CreateNodeCommand(...));

    if (result.isSuccess) {
      emit(state.copyWith(
        nodes: [...state.nodes, result.data],
        isLoading: false,
      ));
    } else {
      emit(state.copyWith(isLoading: false, error: result.error));
    }
  }

  Future<void> _onLoadNodes(NodeLoadEvent event, Emitter emit) async {
    // Read operations can go directly to Repository or use QueryBus
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
    emit(state.copyWith(nodes: [...state.nodes, node]));
  }
}
```

**Event Bus Pattern:**

```dart
// Command Handlers automatically publish events via CommandBus
// No manual event publishing needed - CommandBus does it automatically

// BLoCs subscribe to CommandBus.eventStream for updates
commandBus.eventStream.listen((event) {
  if (event is NodeDataChangedEvent) {
    add(NodeDataChangedInternalEvent(...));
  }
});

// Legacy code may still use AppEventBus (being phased out)
appEventBus.stream.listen((event) {
  // Handle legacy events
});
```

## Coding Standards

This project follows strict coding standards defined in `docs/coding_standards.md`. Key points:

### Type Annotations
- **Public APIs MUST have type annotations**
- Private methods may omit types for brevity
- Use `??` for null-aware operations

### Flutter/Flame Specific
- Use `const` constructors wherever possible
- Flame components: cache Paint/Text objects, don't allocate in `render()`
- Use `existsSync()` instead of `await exists()`
- `withOpacity()` → use `withValues(alpha:)`
- `HasGameRef` → use `HasGameReference`

### Error Handling
- Use typed exceptions, not generic `Exception`
- Avoid catching generic `Exception` - catch specific types
- Implement proper error recovery

### Code Organization
- **Constructors first** - before any class members
- One class per file
- Import order: Dart SDK → Flutter → Third-party → Project → Relative

### Documentation & Comments

**MANDATORY: All code must include complete comments explaining architectural intent**

- **Public APIs MUST have documentation comments** explaining purpose, parameters, and return values
- **Complex logic MUST include inline comments** explaining the "why" (not just the "what")
- **Architectural decisions MUST be documented** - explain why code is structured a certain way

For detailed coding standards in Chinese, see `docs/coding_standards.md`.

## Testing

Tests are organized by layer and functionality in `test/` directory, mirroring the lib/ structure.

**Test Organization:**

```
test/
├── core/                          # Core component tests
│   ├── commands/                  # Command bus tests (concurrency, events)
│   ├── cqrs/                      # Query bus and handler tests
│   ├── events/                    # Event system tests
│   ├── execution/                 # Execution engine boundary tests
│   ├── graph/                     # Graph data structure tests
│   ├── middleware/                # Middleware tests (logging, validation, etc.)
│   ├── plugin/                    # Plugin system tests (lifecycle, hooks, dependencies)
│   ├── repositories/              # Repository tests (basic and advanced)
│   ├── services/                  # Service tests (settings, theme, data recovery)
│   └── ui_layout/                 # UI layout system tests
├── plugins/                       # Plugin-specific tests
│   ├── ai/                        # AI plugin tests
│   ├── converter/                 # Converter plugin tests
│   ├── data_recovery/             # Data recovery plugin tests
│   ├── editor/                    # Editor plugin tests
│   ├── folder/                    # Folder plugin tests
│   ├── graph/                     # Graph plugin tests
│   ├── i18n/                      # i18n plugin tests
│   ├── lua/                       # Lua plugin tests (service, handler, integration)
│   └── search/                    # Search plugin tests
├── integration/                   # Integration tests
│   ├── graph_integration_test.dart
│   └── graph_workflow_integration_test.dart
├── performance/                   # Performance tests
│   ├── cqrs_performance_test.dart
│   └── graph_performance_test.dart
└── test_config.dart               # Test configuration
```

**Running Tests:**
```bash
flutter test                           # Run all tests
flutter test test/core/commands/command_bus_test.dart  # Run specific file
flutter test --coverage                # Run with coverage
flutter test test/plugins/lua/integration/  # Run specific directory
```

**Testing Guidelines:**
- Use Mockito for mocking dependencies (generates .mocks.dart files)
- Test BLoCs in isolation with mock services
- Test command handlers independently
- Test widget interactions with `WidgetTester`
- Integration tests for complex workflows
- Performance tests for critical paths
- Boundary tests for edge cases

**Note:** The test suite includes comprehensive coverage across all layers. Run tests regularly to catch regressions early.

## Plugin Development

### Quick Plugin Template

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
    // Plugin initialization
  }

  @override
  Future<void> onEnable() async {
    // Plugin activation
  }

  @override
  Future<void> onDisable() async {
    // Plugin deactivation
  }

  @override
  List<CommandHandlerBinding> registerCommandHandlers() {
    return [/* Register command handlers */];
  }

  @override
  List<ServiceBinding> registerServices() {
    return [/* Register services */];
  }
}
```

### Service Registration

```dart
@ServiceBinding(
  serviceType: MyService,
  implementationType: MyServiceImpl,
  lifetime: ServiceLifetime.singleton,
)
class MyServiceImpl implements MyService {
  // Implementation
}
```

## UI Hook System

The UI Hook system enables extending the application UI at specific hook points.

**Key Points:**
- UIHookBase is independent of Plugin (simpler lifecycle)
- String-based hook points (supports dynamic registration)
- Semantic priorities (critical, high, medium, low, decorative)
- Inter-hook API communication via HookContext

**Available Hook Points:**
- `main.toolbar` - Main toolbar
- `sidebar.top` / `sidebar.bottom` - Sidebar
- `context_menu.node` / `context_menu.graph` - Context menus
- `status.bar` - Status bar
- `settings` - Settings page

**Lua Dynamic Hooks:**
Lua scripts can register dynamic hooks at runtime:
```lua
-- Register a toolbar button
registerHook("main.toolbar", function(ctx)
    ctx:addButton("myButton", "Click Me", function()
        print("Button clicked!")
    end)
end)
```

See `docs/COMMAND_LINE_GUIDE.md` for complete Lua scripting documentation.

## Code Analysis

### Third-Party Plugin Warnings
Some plugins (like `file_picker`) produce platform integration warnings. Use the provided analyze scripts to filter them out:
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

## Important Notes

### Architecture Patterns
1. **CQRS Pattern**: Separate read (QueryBus with caching) and write (CommandBus with auto-events) operations
2. **Event-Driven**: CommandBus automatically publishes events to eventStream after command execution
3. **Plugin Architecture**: Extend functionality via plugins, not direct modifications
4. **Unified DI**: Single DI container (ServiceRegistry) supporting both Provider and dynamic plugin loading
5. **UI Layout System**: Flexible rendering with multiple backends (Flame/Flutter)
6. **Task Execution**: CPU/GPU task separation for performance optimization

### Development Guidelines
1. **Always regenerate code** after modifying models with `@JsonSerializable` annotation
2. **Provider dependency order is critical** - see dependency injection order above
3. **Don't use `print()`** - use `debugPrint()` or LoggingMiddleware
4. **File I/O should be async** - avoid blocking the UI thread
5. **Flame performance** - cache resources, don't allocate in render()
6. **Error recovery** - app has built-in data recovery on initialization failures
7. **UI Layout** - use UILayoutService for layout operations, support multiple rendering backends
8. **Performance** - use ExecutionEngine for CPU-intensive tasks, leverage spatial indexing

### Command Bus Usage
1. **Write operations** → Always use `CommandBus.dispatch(command)`
2. **Read operations** → Use `QueryBus.dispatch(query)` for complex queries with caching, or Repository directly for simple queries
3. **Business logic** → Implement in Command Handlers, not in BLoCs or Services
4. **Event publishing** → Automatic via CommandBus.eventStream (no manual publishing needed)
5. **Undo support** → Implement `undo()` method in Command if operation should be undoable

**Query Bus Best Practices:**
- Use QueryBus for complex queries that benefit from caching (searches, aggregations)
- Use Repository directly for simple, single-record lookups
- QueryBus provides LRU cache (1000 entries) for CacheableQuery implementations

### BLoC Best Practices
1. **BLoC responsibilities** → Only manage UI state (isLoading, error, selection)
2. **No business logic in BLoCs** → Delegate to CommandBus
3. **Subscribe to CommandBus.eventStream** → React to data changes from other components (primary event source)
4. **Initial events** → Always add initial events when creating BLoCs
5. **State updates** → Update state based on CommandResult, not directly
6. **Read operations** → Use QueryBus for cached queries, Repository for simple lookups

### Plugin Development
1. **Plugin location** → Create plugins in `lib/plugins/{plugin_name}/`
2. **Plugin dependencies** → Always declare in metadata to ensure correct load order
3. **Plugin lifecycle** → Use `onLoad()` for initialization, `onEnable()` for activation
4. **Service registration** → Use `registerServices()` to provide plugin services
5. **Command handlers** → Register via `registerCommandHandlers()` method
6. **UI Hooks** → Extend UI at specific hook points via HookRegistry
7. **API exports** → Export APIs via `exportAPIs()` for inter-plugin communication

### Lua Scripting
1. **Script location** → Store scripts in `data/lua_scripts/` or `data/scripts/`
2. **Security** → Lua scripts run in sandboxed environment with limited APIs
3. **Dynamic hooks** → Scripts can register UI hooks at runtime
4. **Event handling** → Scripts can listen to and emit events
5. **API access** → Available APIs: node operations, graph operations, UI hooks, messaging

See `docs/COMMAND_LINE_GUIDE.md` for complete Lua scripting documentation.

## UI Layout System

The UI Layout System provides flexible node visualization with support for multiple rendering backends.

**Key Components:**

**Coordinate System:**
- World coordinates for node positioning
- Screen coordinate transformation
- Camera transformation support

**Rendering Backends:**
- **FlameRenderer**: Game engine rendering with performance optimizations:
  - Spatial indexing using QuadTree
  - Level-of-detail (LOD) rendering
  - View frustum culling
  - Interactive components (drag, click, zoom)
- **FlutterRenderer**: Native Flutter rendering for simpler use cases

**Layout Strategies:**
- Force-directed layouts
- Hierarchical layouts
- Custom layout algorithms

**Node Templates:**
- Consistent node styling
- Multiple node types (regular, folder, AI)
- Customizable icons and colors
- View modes (titleOnly, compact, fullContent)

**Integration:**
- Tightly integrated with Graph plugin
- BLoC state management for layout changes
- Event-driven updates from CommandBus
- UI Hook support for custom layouts

## Execution Engine

The Execution Engine provides task separation and parallel processing capabilities.

**Architecture:**

**Task Types:**
- **CPU Tasks**: Computation-intensive operations
- **GPU Tasks**: Graphics/visualization operations

**Components:**
- `ExecutionEngine`: Central task coordinator
- `TaskRegistry`: Task registration and management
- `CPUExecutor`: CPU task execution
- **GPUExecutor**: GPU task execution

**Use Cases:**
- Graph layout computations
- Spatial indexing updates
- Batch processing operations
- Performance-critical operations

**Integration:**
- Works with CommandBus for task execution
- Supports asynchronous task scheduling
- Error handling and recovery

## Graph Data Structures

Advanced graph data structures for efficient operations.

**Components:**

**Adjacency List:**
- Efficient graph traversal
- Neighbor queries
- Path finding support

**Spatial Indexing:**
- **QuadTree**: O(log n) spatial queries
- Fast range searches
- Neighbor finding
- Collision detection

**Graph Partitioning:**
- **GraphPartitioner**: Divide large graphs into subgraphs
- **SubgraphCache**: Cache partitioned subgraphs
- Improved performance for large graphs

**Use Cases:**
- Large graph visualization
- Spatial queries
- Graph layout algorithms
- Connection finding

## Metadata System

The metadata system provides extensible node metadata with validation and schema support.

**Components:**
- `metadata_validator.dart` - Validates node metadata against schemas
- `metadata_schema.dart` - Schema definitions for metadata
- `standard_metadata.dart` - Standard metadata types

**Integration:**
- Nodes support arbitrary metadata via YAML frontmatter
- Metadata validation on save
- Schema-based type checking
- Extensible for custom metadata types

**Use Cases:**
- Node categorization
- Custom node properties
- Plugin-specific metadata
- Data validation

## Configuration System

The configuration system provides feature flag management.

**Components:**
- `feature_flags.dart` - Feature flag definitions and management

**Use Cases:**
- Gradual feature rollout
- A/B testing
- Experimental features
- Migration between old and new systems

## Additional Documentation

- `docs/coding_standards.md` - Detailed coding standards and conventions
- `docs/COMMAND_LINE_GUIDE.md` - Command line and Lua scripting guide
- `docs/performance_hotspot_report.md` - Performance analysis and optimization recommendations

**Note:** Some documentation files referenced in older commits may not exist yet. The above files are currently available in the repository.
