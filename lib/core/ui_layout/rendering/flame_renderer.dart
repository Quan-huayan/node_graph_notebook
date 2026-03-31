/// Flame renderer for UI layout system.
///
/// Maps the Hook tree to Flame component tree for graph visualization.
///
/// ## Architecture
///
/// ```
/// UIHookNode (Hook tree)
///     ↓
/// FlameRenderer.render()
///     ↓
/// Flame component tree (PositionComponent, etc.)
///     ↓
/// Flame renders to screen
/// ```
///
/// ## Usage
///
/// ```dart
/// final renderer = const FlameRenderer();
/// final graphHook = layoutService.getHook('graph');
///
/// if (graphHook != null) {
///   final component = renderer.render(
///     graphHook,
///     {'gameWorld': world},
///   );
///
///   world.add(component);
/// }
/// ```
library;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../layout_strategy.dart';
import '../node_attachment.dart';
import '../ui_hook_tree.dart';
import 'renderer_base.dart';

/// Reference to avoid direct Flame import issues.
typedef FlameGame = Game;

/// Typedef for Flame Component to avoid direct import issues.
typedef FlameComponent = Component;

/// Renderer that maps Hook tree to Flame component tree.
///
/// Supports all built-in layout strategies for positioning
/// Flame components in the game world.
///
/// ## Supported Layout Strategies
///
/// - **absolute**: Components positioned at absolute coordinates
/// - **sequential**: Components arranged in sequence (column/row)
/// - **proportional**: Components sized by percentage
/// - **flow**: Components wrap to new lines
/// - **grid**: Components arranged in a grid
class FlameRenderer extends RendererBase<FlameComponent> {
  /// Creates a Flame renderer.
  ///
  /// [nodeComponentBuilder] is optional custom builder for Node components.
  /// If not provided, uses a default placeholder component.
  FlameRenderer({
    this.nodeComponentBuilder,
  });

  /// Custom builder for Node components.
  ///
  /// If provided, this builder is called for each attached Node
  /// to create the Flame component for that Node.
  ///
  /// Parameters:
  /// - `nodeId`: The ID of the Node to render.
  /// - `attachment`: The Node's attachment info.
  /// - `context`: Contains the game world instance.
  final FlameComponent Function(
    String nodeId,
    NodeAttachment attachment,
    Map<String, dynamic> context,
  )? nodeComponentBuilder;

  @override
  String get outputTypeName => 'Component';

  @override
  FlameComponent render(UIHookNode hook, Map<String, dynamic> context) {
    final gameWorld = context['gameWorld'] as FlameGame?;

    // Get layout strategy
    final strategy = hook.layoutConfig.strategy;

    // Render based on strategy
    return switch (strategy) {
      LayoutStrategy.absolute => _renderAbsolute(hook, gameWorld),
      LayoutStrategy.sequential => _renderSequential(hook, gameWorld),
      LayoutStrategy.proportional => _renderProportional(hook, gameWorld),
      LayoutStrategy.flow => _renderFlow(hook, gameWorld),
      LayoutStrategy.grid => _renderGrid(hook, gameWorld),
      LayoutStrategy.custom => _renderCustom(hook, gameWorld),
    };
  }

  @override
  FlameComponent renderAttachedNode(
    NodeAttachment attachment,
    Map<String, dynamic> context,
  ) {
    if (nodeComponentBuilder != null) {
      return nodeComponentBuilder!(
        attachment.nodeId,
        attachment,
        context,
      );
    }

    // Default placeholder component
    return _DefaultNodeComponent(
      nodeId: attachment.nodeId,
      attachment: attachment,
    );
  }

  /// Renders absolute layout.
  ///
  /// Components positioned at absolute coordinates.
  FlameComponent _renderAbsolute(UIHookNode hook, FlameGame? gameWorld) {
    final container = _HookContainerComponent(
      hookId: hook.id,
      size: hook.size,
    );

    // Add child Hooks
    for (final child in hook.children) {
      final childComponent = render(child, {'gameWorld': gameWorld});
      final offset = _calculateChildOffset(child, hook.size);

      if (childComponent is PositionComponent) {
        childComponent.position.setFrom(offset);
      }
      container.add(childComponent);
    }

    // Add attached Nodes
    for (final attachment in hook.attachedNodes.values) {
      final nodeComponent = renderAttachedNode(
        attachment,
        {'gameWorld': gameWorld},
      );
      final offset = _calculateNodeOffset(attachment, hook.size);

      if (nodeComponent is PositionComponent) {
        nodeComponent.position.setFrom(offset);
      }
      container.add(nodeComponent);
    }

    return container;
  }

  /// Renders sequential layout (column or row).
  FlameComponent _renderSequential(UIHookNode hook, FlameGame? gameWorld) {
    final isVertical = hook.layoutConfig.direction == Axis.vertical;
    final config = hook.layoutConfig;

    final container = _HookContainerComponent(
      hookId: hook.id,
      size: hook.size,
    );

    var primaryPos = isVertical ? config.padding.top : config.padding.left;
    final secondaryPos = isVertical ? config.padding.left : config.padding.top;

    // Combine children and attached nodes
    final allItems = [
      ...hook.children.map((child) => _RenderItem(
            id: child.id,
            component: render(child, {'gameWorld': gameWorld}),
            size: child.size,
            isComponent: true,
          )),
      ...hook.attachedNodes.values.map((attachment) => _RenderItem(
            id: attachment.nodeId,
            component: renderAttachedNode(
              attachment,
              {'gameWorld': gameWorld},
            ),
            size: attachment.size ?? const Size(100, 50),
            isComponent: false,
          )),
    ];

    for (final item in allItems) {
      // Calculate position
      final position = isVertical
          ? Vector2(secondaryPos, primaryPos)
          : Vector2(primaryPos, secondaryPos);

      if (item.component is PositionComponent) {
        (item.component as PositionComponent).position.setFrom(position);
      }
      container.add(item.component);

      // Advance position
      primaryPos += isVertical ? item.size.height : item.size.width;
      primaryPos += config.spacing;
    }

    return container;
  }

  /// Renders proportional layout.
  FlameComponent _renderProportional(UIHookNode hook, FlameGame? gameWorld) => _renderSequential(hook, gameWorld); // Similar to sequential but with proportional sizing

  /// Renders flow layout.
  FlameComponent _renderFlow(UIHookNode hook, FlameGame? gameWorld) {
    final config = hook.layoutConfig;
    final isVertical = config.direction == Axis.vertical;

    final container = _HookContainerComponent(
      hookId: hook.id,
      size: hook.size,
    );

    var primaryPos = isVertical ? config.padding.top : config.padding.left;
    var secondaryPos = isVertical ? config.padding.left : config.padding.top;
    var currentSecondaryLineSize = 0.0;

    // Combine children and attached nodes
    final allItems = [
      ...hook.children.map((child) => _RenderItem(
            id: child.id,
            component: render(child, {'gameWorld': gameWorld}),
            size: child.size,
            isComponent: true,
          )),
      ...hook.attachedNodes.values.map((attachment) => _RenderItem(
            id: attachment.nodeId,
            component: renderAttachedNode(
              attachment,
              {'gameWorld': gameWorld},
            ),
            size: attachment.size ?? const Size(100, 50),
            isComponent: false,
          )),
    ];

    final maxSecondary = isVertical ? hook.size.width : hook.size.height;
    final maxSecondaryWithPadding = maxSecondary -
        (isVertical
            ? config.padding.horizontal
            : config.padding.vertical);

    for (final item in allItems) {
      final itemSize = isVertical ? item.size.height : item.size.width;
      final itemCrossSize = isVertical ? item.size.width : item.size.height;

      // Check if we need to wrap to next line
      if (currentSecondaryLineSize + itemCrossSize > maxSecondaryWithPadding &&
          currentSecondaryLineSize > 0) {
        // Wrap to next line
        primaryPos += itemSize;
        primaryPos += config.spacing;
        secondaryPos = isVertical ? config.padding.left : config.padding.top;
        currentSecondaryLineSize = 0;
      }

      // Calculate position
      final position = isVertical
          ? Vector2(secondaryPos, primaryPos)
          : Vector2(primaryPos, secondaryPos);

      if (item.component is PositionComponent) {
        (item.component as PositionComponent).position.setFrom(position);
      }
      container.add(item.component);

      // Advance position
      secondaryPos += itemCrossSize;
      secondaryPos += config.crossAxisSpacing;
      currentSecondaryLineSize += itemCrossSize;
    }

    return container;
  }

  /// Renders grid layout.
  FlameComponent _renderGrid(UIHookNode hook, FlameGame? gameWorld) {
    final config = hook.layoutConfig;
    final columns = config.columns ?? 2;
    final columnCount = columns > 0 ? columns : 2;

    final container = _HookContainerComponent(
      hookId: hook.id,
      size: hook.size,
    );

    // Calculate cell size
    final availableWidth = hook.size.width - config.padding.horizontal;
    final cellWidth =
        (availableWidth - (columns - 1) * config.crossAxisSpacing) /
            columnCount;

    // Combine children and attached nodes
    final allItems = [
      ...hook.children.map((child) => _RenderItem(
            id: child.id,
            component: render(child, {'gameWorld': gameWorld}),
            size: child.size,
            isComponent: true,
          )),
      ...hook.attachedNodes.values.map((attachment) => _RenderItem(
            id: attachment.nodeId,
            component: renderAttachedNode(
              attachment,
              {'gameWorld': gameWorld},
            ),
            size: attachment.size ?? const Size(100, 50),
            isComponent: false,
          )),
    ];

    var col = 0;
    var currentY = config.padding.top;
    var maxRowHeight = 0.0;

    for (final item in allItems) {
      // Calculate position
      final x = config.padding.left + col * (cellWidth + config.crossAxisSpacing);
      final y = currentY;

      if (item.component is PositionComponent) {
        (item.component as PositionComponent).position.setValues(x, y);
      }
      container.add(item.component);

      // Update max row height
      if (item.size.height > maxRowHeight) {
        maxRowHeight = item.size.height;
      }

      // Advance to next cell
      col++;
      if (col >= columnCount) {
        col = 0;
        currentY += maxRowHeight + config.spacing;
        maxRowHeight = 0;
      }
    }

    return container;
  }

  /// Renders custom layout using custom calculator.
  FlameComponent _renderCustom(UIHookNode hook, FlameGame? gameWorld) {
    final calculator = hook.layoutConfig.customCalculator;
    if (calculator == null) {
      return _renderSequential(hook, gameWorld);
    }

    final result = calculator.calculate(hook);
    return _renderFromResult(hook, result, gameWorld);
  }

  /// Renders layout from pre-calculated result.
  FlameComponent _renderFromResult(
    UIHookNode hook,
    LayoutResult result,
    FlameGame? gameWorld,
  ) {
    final container = _HookContainerComponent(
      hookId: hook.id,
      size: hook.size,
    );

    // Add child Hooks
    for (final child in hook.children) {
      final position = result.positions[child.id];
      if (position == null) continue;

      final childComponent = render(child, {'gameWorld': gameWorld});
      final offset = OffsetToVector2(position.toAbsolute(hook.size)).toVector2();

      if (childComponent is PositionComponent) {
        childComponent.position.setFrom(offset);
      }
      container.add(childComponent);
    }

    // Add attached Nodes
    for (final attachment in hook.attachedNodes.values) {
      final position = result.positions[attachment.nodeId];
      if (position == null) continue;

      final nodeComponent = renderAttachedNode(
        attachment,
        {'gameWorld': gameWorld},
      );
      final offset = OffsetToVector2(position.toAbsolute(hook.size)).toVector2();

      if (nodeComponent is PositionComponent) {
        nodeComponent.position.setFrom(offset);
      }
      container.add(nodeComponent);
    }

    return container;
  }

  /// Calculates offset for a child Hook within parent.
  Vector2 _calculateChildOffset(UIHookNode child, Size parentSize) {
    final offset = child.localPosition.toAbsolute(parentSize);
    return OffsetToVector2(offset).toVector2();
  }

  /// Calculates offset for an attached Node within Hook.
  Vector2 _calculateNodeOffset(NodeAttachment attachment, Size hookSize) {
    final offset = attachment.localPosition.toAbsolute(hookSize);
    return OffsetToVector2(offset).toVector2();
  }
}

/// Internal class representing an item to be rendered.
class _RenderItem {
  const _RenderItem({
    required this.id,
    required this.component,
    required this.size,
    required this.isComponent,
  });

  final String id;
  final FlameComponent component;
  final Size size;
  final bool isComponent;
}

/// Container component for Hooks in Flame world.
class _HookContainerComponent extends PositionComponent {
  _HookContainerComponent({
    required this.hookId,
    required Size size,
  }) : super(position: Vector2.zero(), size: SizeToVector2(size).toVector2());

  final String hookId;

  @override
  String toString() => 'HookContainer($hookId)';
}

/// Default placeholder component for Nodes.
class _DefaultNodeComponent extends PositionComponent {
  _DefaultNodeComponent({
    required this.nodeId,
    required this.attachment,
    Offset? position,
  }) : super(position: position != null ? OffsetToVector2(position).toVector2() : Vector2.zero());

  final String nodeId;
  final NodeAttachment attachment;

  @override
  String toString() => 'NodeComponent($nodeId)';
}

/// Extension to convert Offset to Vector2.
extension OffsetToVector2 on Offset {
  /// Converts this Offset to a Flame Vector2.
  Vector2 toVector2() => Vector2(dx, dy);
}

/// Extension to convert Size to Vector2.
extension SizeToVector2 on Size {
  /// Converts this Size to a Flame Vector2.
  Vector2 toVector2() => Vector2(width, height);
}
