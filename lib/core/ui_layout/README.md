# UI Layout System - Phase 1 & 2 Complete

This directory contains the new UI Layout System implementation.

## What's Been Implemented (Phase 1-2)

### Core Abstractions (Phase 1) ✅

1. **Coordinate System** (`coordinate_system.dart`)
   - `LocalPosition` - Position within a Hook's local coordinate system
   - `GlobalPosition` - Absolute position in world coordinates
   - `CoordinateSystem` - Bidirectional conversion utilities

2. **Layout Strategy** (`layout_strategy.dart`)
   - `LayoutStrategy` enum - absolute, sequential, proportional, flow, grid, custom
   - `LayoutConfig` - Hook layout configuration
   - `LayoutCalculator` interface - Custom layout algorithm interface
   - Built-in calculators:
     - `SequentialLayoutCalculator` - Row/column layouts
     - `AbsoluteLayoutCalculator` - Manual positioning
     - `FlowLayoutCalculator` - Wrapping flow layouts
     - `GridLayoutCalculator` - Grid-based layouts

3. **Node Attachment** (`node_attachment.dart`)
   - `NodeAttachment` - Represents a Node attached to a Hook
   - Contains position, z-index, size, and metadata

4. **UI Hook Tree** (`ui_hook_tree.dart`)
   - `UIHookNode` - Hierarchical Hook tree structure
   - Methods for managing children and node attachments
   - Coordinate system hierarchy support
   - Tree traversal and query utilities

### Events System (Phase 5) ✅

1. **Layout Events** (`events/layout_events.dart`)
   - `NodeAttachedEvent` - Node attached to Hook
   - `NodeDetachedEvent` - Node detached from Hook
   - `NodePositionUpdatedEvent` - Node position changed
   - `NodeMovedEvent` - Node moved between Hooks
   - `LayoutRecalculatedEvent` - Hook layout recalculated
   - `HookTreeChangedEvent` - Hook tree structure changed

2. **Node Interaction Events** (`events/node_events.dart`)
   - `NodeInteractionEvent` - Unified interaction event
   - `InteractionType` enum - tap, drag, hover, scroll, etc.
   - `FlutterGestureAdapter` - Convert Flutter gestures
   - `FlameInteractionAdapter` - Convert Flame interactions

### UILayoutService (Phase 2) ✅

1. **Service Implementation** (`ui_layout_service.dart`)
   - Hook tree creation and management
   - Standard Hook point registration
   - Node attachment/detachment/move operations
   - Layout recalculation coordination
   - Layout state persistence (SharedPreferences)
   - Event publishing for all operations

## What's Next (Phase 3-6)

### Phase 3: Rendering Integration
- `rendering/flutter_renderer.dart` - Map Hook tree → Flutter Widget tree
- `rendering/flame_renderer.dart` - Map Hook tree → Flame component tree
- Integrate with existing UI (Sidebar, Toolbar)

### Phase 4: Node Model Refactoring
- Remove `position` field from Node model
- Add dual rendering interface (`buildFlutterWidget()`, `buildFlameComponent()`)
- Remove `nodePositions` from Graph model
- Create migration script

### Phase 5: Plugin Integration (Partial)
- Node template system (`node_template.dart`)
- Update Plugin base with `registerNodeTemplates()`
- Complete plugin integration

### Phase 6: Migration and Cleanup
- Migrate existing plugins to new system
- Remove deprecated code
- Update documentation

## Architecture Overview

```
UILayoutService (service)
  ↓
Hook Tree (UIHookNode hierarchy)
  ↓
Node Attachments (NodeAttachment in Hooks)
  ↓
Layout Calculators (position children)
  ↓
Renderers (Flutter Widget tree / Flame components)
```

## Key Design Principles

1. **Container vs Content Separation**
   - Hooks (containers) decide how to arrange children
   - Nodes (content) decide how to render themselves
   - Position is a relationship, not a property

2. **Hierarchical Coordinate Systems**
   - Each Hook has its own local coordinate system
   - Positions are relative to parent Hook
   - Convert between local and global as needed

3. **Event-Driven Updates**
   - All operations publish events
   - UI components subscribe to events
   - Automatic UI updates

4. **Persistent Layout State**
   - Node attachments saved to SharedPreferences
   - Automatic restoration on startup
   - Manual move operations persist immediately

## Usage Examples

### Initialize Service

```dart
final layoutService = UILayoutService(eventBus: eventBus);
await layoutService.initialize();
```

### Attach Node to Hook

```dart
await layoutService.attachNode(
  nodeId: 'node-1',
  hookId: 'sidebar',
  position: LocalPosition.absolute(10, 20),
);
```

### Move Node Between Hooks

```dart
await layoutService.moveNode(
  nodeId: 'node-1',
  targetHookId: 'graph',
  newPosition: LocalPosition.absolute(100, 200),
);
```

### Get Hook for Rendering

```dart
final sidebarHook = layoutService.getHook('sidebar');
if (sidebarHook != null) {
  // Use FlutterRenderer or FlameRenderer
  final renderer = FlutterRenderer();
  final widget = renderer.render(sidebarHook, context);
}
```

## Testing Status

- ✅ Core models implemented
- ⏳ Unit tests needed
- ⏳ Integration tests needed
- ⏳ Widget tests needed

## Dependencies

- `flutter:` Flutter SDK
- `shared_preferences:` For layout persistence
- `package:flutter/material.dart:` Core Flutter widgets

## Files Created

1. `lib/core/ui_layout/coordinate_system.dart`
2. `lib/core/ui_layout/layout_strategy.dart`
3. `lib/core/ui_layout/node_attachment.dart`
4. `lib/core/ui_layout/ui_hook_tree.dart`
5. `lib/core/ui_layout/ui_layout_service.dart`
6. `lib/core/ui_layout/events/layout_events.dart`
7. `lib/core/ui_layout/events/node_events.dart`
8. `lib/core/ui_layout/README.md` (this file)

## Standard Hook Points

The following Hook points are registered by default:

- `root` - Root Hook
- `main.toolbar` - Main toolbar
- `sidebar` - Sidebar container
- `sidebar.top` - Sidebar tab bar
- `sidebar.bottom` - Sidebar content
- `graph` - Graph container
- `context_menu.node` - Node context menu
- `context_menu.graph` - Graph context menu
- `status.bar` - Status bar
- `settings` - Settings page
