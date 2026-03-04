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

The application follows **Clean Architecture** with **Provider** state management. The dependency injection order is critical:

### Dependency Layers (in order)

```txt
Repository Layer (data access)
    ↓
Service Layer (business logic)
    ↓
Model Layer (state management)
    ↓
UI Layer (widgets)
```

### Key Architectural Patterns

**1. "Everything is a Node" Philosophy**

- All content inherits from base `Node` class
- Node types: `concept`, `content`, `folder`, etc.
- Relationships managed through `NodeReference` objects
- Position and size tracked for visual layout

**2. Provider Organization** (see `lib/app.dart:91-127`)

```dart
MultiProvider(
  providers: [
    // 1. Settings services (global state)
    ChangeNotifierProvider<SettingsService>,
    ChangeNotifierProvider<ThemeService>,

    // 2. Repository layer (data access)
    Provider<NodeRepository>,
    Provider<GraphRepository>,

    // 3. Service layer (business logic)
    Provider<NodeService>,
    Provider<GraphService>,

    // 4. Model layer (state management)
    ChangeNotifierProvider<NodeModel>,
    ChangeNotifierProvider<GraphModel>,
    ChangeNotifierProvider<UIModel>,
  ],
)
```

**3. Provider Usage Rules**

- `context.watch<T>()` - when widget needs to rebuild on state changes
- `context.read<T>()` - for callbacks/event handlers (no rebuild)
- `context.select<T, R>()` - watch specific properties only

### Core Components

**Data Layer** (`lib/core/`)

- `models/` - Core data models (Node, Graph, NodeReference, etc.)
- `repositories/` - File-based data persistence (FileSystemNodeRepository, FileSystemGraphRepository)
- `services/` - Business logic (NodeService, GraphService, SettingsService, ThemeService, ExportService)

**UI Layer** (`lib/ui/`)

- `models/` - State management models (NodeModel, GraphModel, UIModel)
- `pages/` - Full-screen pages
- `widgets/` - Reusable components
- `dialogs/` - Dialogs and modals

**Visualization** (`lib/flame/`)

- Flame engine components for interactive node graphs
- Custom rendering and interaction handling

**AI Integration** (`lib/ai/`)

- Placeholder for OpenAI/Anthropic clients
- Requires API keys configuration

### Data Persistence

- **Nodes**: Stored as Markdown files with JSON metadata in `data/nodes/`
- **Graphs**: JSON files defining node connections in `data/graphs/`
- **Settings**: SharedPreferences for app configuration

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

Tests are located in `test/` directory:

- Widget tests: `test/widget_test.dart`
- Use Mockito for mocking dependencies
- Run with: `flutter test`

## Important Notes

1. **Always regenerate code** after modifying models with `@JsonSerializable` annotation
2. **Provider dependency order matters** - repositories → services → models
3. **Don't use `print()`** - use `debugPrint()` or a logging service
4. **File I/O should be async** - avoid blocking the UI thread with sync operations
5. **Flame performance** - cache Paint/Text objects, don't allocate in `render()` method
6. **Error recovery** - app has built-in data recovery on initialization failures
