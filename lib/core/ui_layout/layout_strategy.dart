/// Layout strategy system for UI Hook tree.
///
/// This module defines the layout algorithms used by Hooks to arrange
/// their children and attached nodes.
///
/// ## Key Concepts
///
/// - **LayoutStrategy**: Enum defining available layout algorithms
/// - **LayoutConfig**: Configuration for a Hook's layout behavior
/// - **LayoutCalculator**: Interface for implementing custom layouts
/// - **Built-in calculators**: Sequential, absolute, proportional, flow, grid
///
/// ## Usage
///
/// ```dart
/// // Create a Hook with vertical sequential layout
/// final hook = UIHookNode(
///   hookPointId: 'sidebar',
///   layoutConfig: LayoutConfig(
///     strategy: LayoutStrategy.sequential,
///     direction: Axis.vertical,
///   ),
/// );
///
/// // Calculate positions for children
/// final calculator = SequentialLayoutCalculator();
/// final positions = calculator.calculate(hook);
/// ```
library;

import 'package:flutter/material.dart';
import 'coordinate_system.dart';
import 'ui_hook_tree.dart';

/// Available layout strategies for arranging children in a Hook.
///
/// Each strategy defines a different algorithm for positioning children:
/// - **absolute**: Children positioned manually via LocalPosition
/// - **sequential**: Children arranged in sequence (row or column)
/// - **proportional**: Children sized by percentage, arranged sequentially
/// - **flow**: Children wrap to new lines when space runs out
/// - **grid**: Children arranged in a grid with fixed columns
/// - **custom**: Use a custom LayoutCalculator implementation
enum LayoutStrategy {
  /// Children positioned absolutely using their LocalPosition.
  ///
  /// Parent does not arrange children; each child's position is
  /// determined solely by its LocalPosition.
  absolute,

  /// Children arranged in sequence (row or column).
  ///
  /// Children are laid out one after another in the specified direction.
  /// Positions are calculated automatically based on order and spacing.
  sequential,

  /// Children sized proportionally and arranged sequentially.
  ///
  /// Each child's size is a percentage of the parent's size.
  /// Useful for responsive layouts (e.g., 30%, 70% split).
  proportional,

  /// Children wrap to new lines when space runs out.
  ///
  /// Similar to Flutter's Wrap widget. Children flow in the
  /// specified direction and wrap when they exceed the parent's bounds.
  flow,

  /// Children arranged in a grid.
  ///
  /// Children are organized into rows with a fixed number of columns.
  /// Each cell has equal size (or can be customized via columnSpan/rowSpan).
  grid,

  /// Custom layout calculator provided by the user.
  ///
  /// Allows plugin authors to implement custom layout algorithms.
  custom,
}

/// Configuration for a Hook's layout behavior.
///
/// Defines how a Hook arranges its children and attached nodes.
///
/// ## Examples
///
/// ```dart
/// // Vertical sidebar layout
/// final sidebar = LayoutConfig(
///   strategy: LayoutStrategy.sequential,
///   direction: Axis.vertical,
///   spacing: 8.0,
///   padding: EdgeInsets.all(16.0),
/// );
///
/// // Grid layout for buttons
/// final grid = LayoutConfig(
///   strategy: LayoutStrategy.grid,
///   columns: 3,
///   spacing: 4.0,
/// );
///
/// // Custom layout
/// final custom = LayoutConfig(
///   strategy: LayoutStrategy.custom,
///   customCalculator: MyCustomLayoutCalculator(),
/// );
/// ```
@immutable
class LayoutConfig {
  /// Creates a layout configuration.
  ///
  /// [strategy] is the layout algorithm to use.
  /// [direction] is the primary axis for sequential/flow layouts (default: vertical).
  /// [spacing] is the space between children in the primary axis.
  /// [crossAxisSpacing] is the space between children in the secondary axis (for grid/flow).
  /// [padding] is the padding around all children.
  /// [columns] is the number of columns for grid layout.
  /// [customCalculator] is the custom calculator for LayoutStrategy.custom.
  const LayoutConfig({
    required this.strategy,
    this.direction = Axis.vertical,
    this.spacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.padding = EdgeInsets.zero,
    this.columns,
    this.customCalculator,
  }) : assert(
          strategy != LayoutStrategy.custom || customCalculator != null,
          'customCalculator must be provided for LayoutStrategy.custom',
        );

  /// The layout strategy to use.
  final LayoutStrategy strategy;

  /// The primary axis direction for sequential/flow layouts.
  final Axis direction;

  /// Space between children in the primary axis.
  final double spacing;

  /// Space between children in the secondary axis (for grid/flow).
  final double crossAxisSpacing;

  /// Padding around all children.
  final EdgeInsets padding;

  /// Number of columns for grid layout.
  final int? columns;

  /// Custom layout calculator for LayoutStrategy.custom.
  final LayoutCalculator? customCalculator;

  /// Creates a copy of this config with some fields replaced.
  LayoutConfig copyWith({
    LayoutStrategy? strategy,
    Axis? direction,
    double? spacing,
    double? crossAxisSpacing,
    EdgeInsets? padding,
    int? columns,
    LayoutCalculator? customCalculator,
  }) => LayoutConfig(
      strategy: strategy ?? this.strategy,
      direction: direction ?? this.direction,
      spacing: spacing ?? this.spacing,
      crossAxisSpacing: crossAxisSpacing ?? this.crossAxisSpacing,
      padding: padding ?? this.padding,
      columns: columns ?? this.columns,
      customCalculator: customCalculator ?? this.customCalculator,
    );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LayoutConfig &&
        other.strategy == strategy &&
        other.direction == direction &&
        other.spacing == spacing &&
        other.crossAxisSpacing == crossAxisSpacing &&
        other.padding == padding &&
        other.columns == columns &&
        other.customCalculator == customCalculator;
  }

  @override
  int get hashCode => Object.hash(
        strategy,
        direction,
        spacing,
        crossAxisSpacing,
        padding,
        columns,
        customCalculator,
      );

  @override
  String toString() => 'LayoutConfig(strategy: $strategy, direction: $direction, spacing: $spacing)';
}

/// Result of a layout calculation.
///
/// Contains the calculated position for each child or attached node.
class LayoutResult {
  /// Creates a layout result.
  const LayoutResult({
    required this.positions,
    required this.totalSize,
  });

  /// Map of child/node ID to its calculated local position.
  final Map<String, LocalPosition> positions;

  /// The total size required for this layout.
  ///
  /// For sequential layouts, this is the accumulated size of all children
  /// plus spacing and padding.
  final Size totalSize;
}

/// Interface for implementing custom layout calculators.
///
/// Layout calculators are responsible for determining the positions
/// of children and attached nodes within a Hook.
///
/// ## Implementing a Custom Layout
///
/// ```dart
/// class MyCustomLayoutCalculator implements LayoutCalculator {
///   @override
///   LayoutResult calculate(UIHookNode hook) {
///     final positions = <String, LocalPosition>{};
///
///     // Calculate positions for children
///     double y = hook.layoutConfig.padding.top;
///     for (final child in hook.children) {
///       positions[child.id] = LocalPosition.absolute(0, y);
///       y += child.size.height + hook.layoutConfig.spacing;
///     }
///
///     // Calculate positions for attached nodes
///     for (final attachment in hook.attachedNodes) {
///       positions[attachment.nodeId] = LocalPosition.absolute(0, y);
///       y += 50.0 + hook.layoutConfig.spacing; // Assume fixed node height
///     }
///
///     return LayoutResult(
///       positions: positions,
///       totalSize: Size(hook.size.width, y + hook.layoutConfig.padding.bottom),
///     );
///   }
/// }
/// ```
abstract class LayoutCalculator {
  /// Calculates positions for all children and attached nodes in a Hook.
  ///
  /// [hook] is the Hook to calculate layout for.
  ///
  /// Returns a [LayoutResult] containing the calculated positions and total size.
  LayoutResult calculate(UIHookNode hook);
}

/// Sequential layout calculator for row/column layouts.
///
/// Arranges children in sequence along a primary axis with optional spacing.
/// This is the default calculator for LayoutStrategy.sequential.
///
/// ## Example
///
/// Vertical layout (column):
/// ```
/// ┌──────────────────┐
/// │ Padding Top      │
/// ├──────────────────┤  spacing
/// │ Child 1          │
/// ├──────────────────┤  spacing
/// │ Child 2          │
/// ├──────────────────┤  spacing
/// │ Child 3          │
/// └──────────────────┘
/// ```
class SequentialLayoutCalculator implements LayoutCalculator {
  /// Creates a sequential layout calculator.
  const SequentialLayoutCalculator();

  @override
  LayoutResult calculate(UIHookNode hook) {
    final config = hook.layoutConfig;
    final positions = <String, LocalPosition>{};

    final isVertical = config.direction == Axis.vertical;

    // Calculate positions for children
    var primaryPos = isVertical ? config.padding.top : config.padding.left;
    final secondaryPos = isVertical ? config.padding.left : config.padding.top;

    // Combine children and attached nodes for layout
    final allItems = [
      ...hook.children.map((child) => _LayoutItem(child.id, child.size, true)),
      ...hook.attachedNodes.entries.map((entry) => _LayoutItem(
            entry.value.nodeId,
            entry.value.size ?? const Size(100, 50), // Default node size
            false,
          )),
    ];

    for (final item in allItems) {
      // Calculate position based on direction
      final position = isVertical
          ? LocalPosition.absolute(secondaryPos, primaryPos)
          : LocalPosition.absolute(primaryPos, secondaryPos);

      positions[item.id] = position;

      // Advance position
      primaryPos += isVertical ? item.size.height : item.size.width;
      primaryPos += config.spacing;
    }

    // Calculate total size
    final primaryAxisSize = primaryPos +
        (isVertical ? config.padding.bottom : config.padding.right);
    final secondaryAxisSize = hook.size.width;

    final totalSize = isVertical
        ? Size(secondaryAxisSize, primaryAxisSize)
        : Size(primaryAxisSize, secondaryAxisSize);

    return LayoutResult(positions: positions, totalSize: totalSize);
  }
}

/// Absolute layout calculator.
///
/// Does not calculate positions; each child/node uses its pre-existing
/// LocalPosition. This is the default for LayoutStrategy.absolute.
class AbsoluteLayoutCalculator implements LayoutCalculator {
  /// Creates an absolute layout calculator.
  const AbsoluteLayoutCalculator();

  @override
  LayoutResult calculate(UIHookNode hook) {
    final positions = <String, LocalPosition>{};

    // Use existing positions for children
    for (final child in hook.children) {
      positions[child.id] = child.localPosition;
    }

    // Use existing positions for attached nodes
    for (final attachment in hook.attachedNodes.values) {
      positions[attachment.nodeId] = attachment.localPosition;
    }

    // Total size is the Hook's size (already known)
    return LayoutResult(positions: positions, totalSize: hook.size);
  }
}

/// Flow layout calculator for wrapping children.
///
/// Similar to Flutter's Wrap widget. Children flow in the primary
/// direction and wrap to the next line when they exceed the parent's bounds.
///
/// ## Example (Horizontal Flow)
///
/// ```
/// ┌──────────────────────────┐
/// │ Child1  Child2  Child3    │
/// │ Child4  Child5            │
/// └──────────────────────────┘
/// ```
class FlowLayoutCalculator implements LayoutCalculator {
  /// Creates a flow layout calculator.
  const FlowLayoutCalculator();

  @override
  LayoutResult calculate(UIHookNode hook) {
    final config = hook.layoutConfig;
    final positions = <String, LocalPosition>{};

    final isVertical = config.direction == Axis.vertical;

    // Combine children and attached nodes
    final allItems = [
      ...hook.children.map((child) => _LayoutItem(child.id, child.size, true)),
      ...hook.attachedNodes.entries.map((entry) => _LayoutItem(
            entry.value.nodeId,
            entry.value.size ?? const Size(100, 50),
            false,
          )),
    ];

    var primaryPos = isVertical ? config.padding.top : config.padding.left;
    var secondaryPos = isVertical ? config.padding.left : config.padding.top;
    var currentSecondaryLineSize = 0.0;

    for (final item in allItems) {
      final itemSize = isVertical ? item.size.height : item.size.width;
      final itemCrossSize = isVertical ? item.size.width : item.size.height;
      final maxSecondary = isVertical ? hook.size.width : hook.size.height;
      final maxSecondaryWithPadding = maxSecondary -
          (isVertical
              ? config.padding.horizontal
              : config.padding.vertical);

      // Check if we need to wrap to next line
      if (currentSecondaryLineSize + itemCrossSize > maxSecondaryWithPadding &&
          currentSecondaryLineSize > 0) {
        // Wrap to next line
        primaryPos += isVertical ? itemSize : itemCrossSize;
        primaryPos += config.spacing;
        secondaryPos = isVertical ? config.padding.left : config.padding.top;
        currentSecondaryLineSize = 0;
      }

      // Calculate position
      final position = isVertical
          ? LocalPosition.absolute(secondaryPos, primaryPos)
          : LocalPosition.absolute(primaryPos, secondaryPos);

      positions[item.id] = position;

      // Advance position
      secondaryPos += itemCrossSize;
      secondaryPos += config.crossAxisSpacing;
      currentSecondaryLineSize += itemCrossSize;
    }

    // Total size is the Hook's size (children are clipped if they overflow)
    return LayoutResult(positions: positions, totalSize: hook.size);
  }
}

/// Grid layout calculator.
///
/// Arranges children in a grid with a fixed number of columns.
/// Each cell has equal size (can be customized in future with columnSpan/rowSpan).
///
/// ## Example (3 columns)
///
/// ```
/// ┌──────────┬──────────┬──────────┐
/// │ Cell 1   │ Cell 2   │ Cell 3   │
/// ├──────────┼──────────┼──────────┤
/// │ Cell 4   │ Cell 5   │ Cell 6   │
/// └──────────┴──────────┴──────────┘
/// ```
class GridLayoutCalculator implements LayoutCalculator {
  /// Creates a grid layout calculator.
  const GridLayoutCalculator();

  @override
  LayoutResult calculate(UIHookNode hook) {
    final config = hook.layoutConfig;
    final positions = <String, LocalPosition>{};

    final columns = config.columns ?? 2;
    final columnCount = columns > 0 ? columns : 2;

    // Calculate cell size
    final availableWidth = hook.size.width - config.padding.horizontal;
    final cellWidth = (availableWidth -
            (columns - 1) * config.crossAxisSpacing) /
        columnCount;

    // Combine children and attached nodes
    final allItems = [
      ...hook.children.map((child) => _LayoutItem(child.id, child.size, true)),
      ...hook.attachedNodes.entries.map((entry) => _LayoutItem(
            entry.value.nodeId,
            entry.value.size ?? const Size(100, 50),
            false,
          )),
    ];

    var col = 0;
    var currentY = config.padding.top;

    var maxRowHeight = 0.0;

    for (final item in allItems) {
      // Calculate position
      final x =
          config.padding.left + col * (cellWidth + config.crossAxisSpacing);
      final y = currentY;

      positions[item.id] = LocalPosition.absolute(x, y);

      // Update max row height
      if (item.size.height > maxRowHeight) {
        maxRowHeight = item.size.height;
      }

      // Advance to next cell
      col++;
      if (col >= columnCount) {
        col = 0;
        currentY += maxRowHeight + config.spacing;
        maxRowHeight = 0.0;
      }
    }

    // Calculate total height
    final totalHeight = currentY + maxRowHeight + config.padding.bottom;

    return LayoutResult(
      positions: positions,
      totalSize: Size(hook.size.width, totalHeight),
    );
  }
}

/// Internal class representing an item to be laid out.
class _LayoutItem {
  const _LayoutItem(this.id, this.size, this.isChild);

  final String id;
  final Size size;
  final bool isChild;
}
