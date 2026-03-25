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

## Architecture Status

**Implementation Complete (100%)**

The refactoring has successfully introduced:
- **Command Bus**: Centralized business logic execution with middleware pipeline
- **CQRS Pattern**: Complete separation of read (Repository) and write (Command) operations
- **Plugin System**: Fully functional plugin architecture with UI hooks, service providers, and middleware plugins
- **BLoC Restructuring**: BLoCs now only manage UI state, all business logic in Command Handlers
- **Event-Driven Architecture**: EventBus for cross-component communication
- **Unified DI Container**: Single dependency injection system supporting both Provider and dynamic plugin loading

**Remaining Work:**
- Test coverage for new Command Handlers
- Performance optimization for large datasets
- Documentation updates for plugin development

## Architecture Pattern

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
- `Node` - Base class for all content elements
- `Graph` - Manages node connections and relationships
- `Connection` - Defines relationships between nodes
- `NodeReference` - Reference objects for node relationships
- `MetadataIndex` - Efficient indexing for fast node lookups

**Repositories** (`repositories/`):
- `FileSystemNodeRepository` - Node storage as Markdown files
- `FileSystemGraphRepository` - Graph storage as JSON files
- `MetadataIndex` - Fast metadata indexing system

**Command System** (`commands/`):
- `command_bus.dart` - Central command dispatcher with middleware pipeline
- `command.dart` - Command base classes with optional undo support
- `command_result.dart` - Type-safe result wrapper
- `command_handler.dart` - Handler interface for commands

**Plugin System** (`plugin/`):
- `plugin.dart` - Base Plugin interface and lifecycle
- `plugin_manager.dart` - Plugin lifecycle management
- `service_registry.dart` - Unified dependency injection container
- `ui_hooks/` - UI Hook system (refactored 2026-03-17)

**Event System** (`events/`):
- `AppEventBus` - Singleton for cross-component communication

### Plugin Architecture (`lib/plugins/`)

**Plugin Structure:**
```
{plugin_name}/
├── command/        # Command definitions
├── handler/        # Command handlers
├── service/        # Business logic services
├── bloc/           # State management BLoCs
└── {plugin_name}_plugin.dart  # Main plugin file
```

**Key Plugins:**
- `graph/` - Core node and graph management with Flame integration
- `ai/` - AI integration features
- `editor/` - Text editing with Markdown support
- `search/` - Node search functionality
- `layout/` - Graph layout algorithms
- `converter/` - Import/export functionality
- `settings/` - Application settings management
- `builtin_middlewares/` - Logging, Validation, Transaction, Undo middlewares

### UI Layer (`lib/ui/`)

- `bloc/ui_bloc.dart` - Core UI state management
- `pages/` - Full-screen pages
- `widgets/` - Reusable components
- `dialogs/` - Dialogs and modals
- `views/` - View widgets (graph view, folder tree, etc.)

### Visualization (`lib/flame/`)

Flame engine components for interactive node graphs with custom rendering and interaction handling.

### Data Persistence

- **Nodes**: Markdown files with JSON metadata in `data/nodes/`
- **Graphs**: JSON files defining node connections in `data/graphs/`
- **Settings**: SharedPreferences (async) for app configuration
- **Search Presets**: Stored in SharedPreferences via SearchPresetService

## Dependency Injection Order

The application initializes dependencies in strict layers using **DynamicProviderWidget**:

1. **ServiceRegistry** - Core dependencies (Repositories, CommandBus, EventBus)
2. **Settings/Theme** - Plugins may need these during initialization
3. **Repositories** - All services depend on data access
4. **EventBus** - Command handlers and services need event publishing
5. **CommandBus** - Handlers need all services registered first
6. **UI BLoC** - Core UI state management
7. **Plugin System** - HookRegistry and PluginManager
8. **Plugin BLoCs** - Plugin BLoCs depend on plugin services

**Key Points:**
- Plugins are loaded **before** UI renders
- Plugin services are automatically injected via DynamicProviderWidget
- Provider tree rebuilds when plugins load/unload
- Plugins can access their own services in `onLoad()`

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
    emit(state.copyWith(nodes: [...state.nodes, node]));
  }
}
```

**Event Bus Pattern:**

```dart
// Command Handlers publish events after operations
eventBus.publish(NodeDataChangedEvent(
  changedNodes: [updatedNode],
  action: DataChangeAction.update,
));

// BLoCs subscribe to EventBus for updates
eventBus.stream.listen((event) {
  if (event is NodeDataChangedEvent) {
    add(NodeDataChangedInternalEvent(...));
  }
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

## Testing

Tests are organized by layer and functionality in `test/` directory.

**Running Tests:**
```bash
flutter test                           # Run all tests
flutter test test/bloc/graph/graph_bloc_test.dart  # Run specific file
flutter test --coverage                # Run with coverage
```

**Testing Guidelines:**
- Use Mockito for mocking dependencies
- Test BLoCs in isolation with mock services
- Test widget interactions with `WidgetTester`

⚠️ **Important:** See `docs/testing_guidelines.md` for comprehensive testing guidelines, including:
- Test organization and structure
- How to avoid "fake tests" (tests that don't provide real value)
- Test value assessment and priority guidelines
- Examples of good tests
- Known issues and action items

## Plugin Development

For detailed plugin development guidance, see `docs/plugin_development.md`, which covers:
- Plugin types (Service, UI Hook, Middleware)
- Plugin structure and lifecycle
- Command and Handler development
- Middleware development
- Service bindings and dependency injection
- Plugin dependencies and API exports
- Example plugins and best practices

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
  List<CommandHandlerBinding> registerCommandHandlers() {
    return [/* Register command handlers */];
  }

  @override
  List<ServiceBinding> registerServices() {
    return [/* Register services */];
  }

  @override
  List<HookFactory> registerHooks() {
    return [/* Register UI hooks */];
  }
}
```

## UI Hook System

The UI Hook system enables extending the application UI at specific hook points. For comprehensive documentation, see `docs/ui_hook_system.md`.

**Key Points:**
- UIHookBase is independent of Plugin (simpler lifecycle)
- String-based hook points (supports dynamic registration)
- Semantic priorities (critical, high, medium, low, decorative)
- Inter-hook API communication

**Available Hook Points:**
- `main.toolbar` - Main toolbar
- `sidebar.top` / `sidebar.bottom` - Sidebar
- `context_menu.node` / `context_menu.graph` - Context menus
- `status.bar` - Status bar
- `settings` - Settings page

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
1. **CQRS Pattern**: Separate read (Repository) and write (CommandBus) operations
2. **Event-Driven**: Use EventBus for cross-component communication
3. **Plugin Architecture**: Extend functionality via plugins, not direct modifications
4. **Unified DI**: Single DI container (ServiceRegistry) supporting both Provider and dynamic plugin loading

### Development Guidelines
1. **Always regenerate code** after modifying models with `@JsonSerializable` annotation
2. **Provider dependency order is critical** - see dependency injection order above
3. **Don't use `debugPrint()`** - use `debugPrint()` or LoggingMiddleware
4. **File I/O should be async** - avoid blocking the UI thread
5. **Flame performance** - cache resources, don't allocate in render()
6. **Error recovery** - app has built-in data recovery on initialization failures

### Command Bus Usage
1. **Write operations** → Always use `CommandBus.dispatch(command)`
2. **Read operations** → Use `Repository` directly
3. **Business logic** → Implement in Command Handlers, not in BLoCs or Services
4. **Event publishing** → Publish events in Command Handlers after data changes
5. **Undo support** → Implement `undo()` method in Command if operation should be undoable

### BLoC Best Practices
1. **BLoC responsibilities** → Only manage UI state (isLoading, error, selection)
2. **No business logic in BLoCs** → Delegate to CommandBus
3. **Subscribe to EventBus** → React to data changes from other components
4. **Initial events** → Always add initial events when creating BLoCs
5. **State updates** → Update state based on CommandResult, not directly

### Plugin Development
1. **Plugin location** → Create plugins in `lib/plugins/{plugin_name}/`
2. **Plugin dependencies** → Always declare in metadata to ensure correct load order
3. **Plugin lifecycle** → Use `onLoad()` for initialization, `onEnable()` for activation
4. **Service registration** → Use `registerServices()` to provide plugin services
5. **Command handlers** → Register via `registerCommandHandlers()` method
6. **UI Hooks** → Extend UI at specific hook points via HookRegistry
7. **API exports** → Export APIs via `exportAPIs()` for inter-plugin communication

## Additional Documentation

- `docs/coding_standards.md` - Detailed coding standards
- `docs/testing_guidelines.md` - Comprehensive testing guidelines
- `docs/plugin_development.md` - Plugin development guide
- `docs/ui_hook_system.md` - UI Hook system architecture
- `docs/ui_hook_migration_deprecations.md` - UI Hook migration guide
- `docs/design/` - Design documents
- `docs/test_analysis_report.md` - Test analysis report
