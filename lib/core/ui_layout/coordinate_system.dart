/// Coordinate system utilities for UI layout management.
///
/// This module provides types and utilities for converting between local
/// and global coordinate systems in the hierarchical Hook tree structure.
///
/// ## Key Concepts
///
/// - **LocalPosition**: Position within a Hook's local coordinate system
/// - **GlobalPosition**: Absolute position in world coordinates
/// - **CoordinateSystem**: Utility class for bidirectional conversion
///
/// ## Usage
///
/// ```dart
/// final localPos = LocalPosition(10.0, 20.0);
/// final globalPos = hook.localToGlobal(localPos);
/// final localAgain = hook.globalToLocal(globalPos);
/// ```
library;

import 'package:flutter/material.dart';
import 'ui_hook_tree.dart';

/// Position within a Hook's local coordinate system.
///
/// Local positions are relative to their parent Hook's origin.
/// They support multiple positioning strategies:
/// - **Absolute**: Exact pixel coordinates
/// - **Proportional**: Percentage of parent size (0.0-1.0)
/// - **Sequential**: Position in flow (not applicable for x/y)
/// - **Fill**: Special value indicating node fills available space
///
/// ## Examples
///
/// ```dart
/// // Absolute positioning (100px right, 200px down from parent origin)
/// final absolutePos = LocalPosition.absolute(100.0, 200.0);
///
/// // Proportional positioning (50% right, 75% down from parent origin)
/// final proportionalPos = LocalPosition.proportional(0.5, 0.75);
///
/// // Sequential positioning (3rd item in flow)
/// final sequentialPos = LocalPosition.sequential(index: 2);
///
/// // Fill positioning (occupy all available space)
/// final fillPos = LocalPosition.fill();
/// ```
@immutable
class LocalPosition {
  /// Creates an absolute local position.
  ///
  /// [x] and [y] are in pixels relative to parent Hook's origin.
  const LocalPosition.absolute(this.x, this.y)
      : type = PositionType.absolute,
        proportionalValue = null;

  /// Creates a proportional local position.
  ///
  /// [x] and [y] are values between 0.0 and 1.0, representing
  /// percentages of the parent Hook's size.
  const LocalPosition.proportional(this.x, this.y)
      : type = PositionType.proportional,
        proportionalValue = null;

  /// Creates a sequential position for flow-based layouts.
  ///
  /// The [index] determines the position in the sequential flow.
  /// For example, index 2 means this is the 3rd item.
  LocalPosition.sequential({required int index})
      : x = index.toDouble(),
        y = 0.0,
        type = PositionType.sequential,
        proportionalValue = null;

  /// Creates a fill position that occupies all available space.
  ///
  /// This is useful for nodes that should stretch to fill their container.
  const LocalPosition.fill()
      : x = 0.0,
        y = 0.0,
        type = PositionType.fill,
        proportionalValue = null;

  /// The x-coordinate value.
  ///
  /// Interpretation depends on [PositionType]:
  /// - absolute: pixels
  /// - proportional: 0.0-1.0 (percentage)
  /// - sequential: index in flow
  /// - fill: ignored (always 0.0)
  final double x;

  /// The y-coordinate value.
  ///
  /// Interpretation depends on [PositionType]:
  /// - absolute: pixels
  /// - proportional: 0.0-1.0 (percentage)
  /// - sequential: ignored (always 0.0)
  /// - fill: ignored (always 0.0)
  final double y;

  /// The type of positioning strategy.
  final PositionType type;

  /// Optional proportional value for advanced layouts.
  ///
  /// This can be used for custom positioning strategies that need
  /// additional proportional information beyond x/y.
  final double? proportionalValue;

  /// Returns the absolute pixel position for a given parent size.
  ///
  /// Converts this local position to absolute pixels based on the
  /// parent Hook's size.
  ///
  /// [parentSize] is the size of the parent Hook.
  Offset toAbsolute(Size parentSize) => switch (type) {
      PositionType.absolute => Offset(x, y),
      PositionType.proportional => Offset(
          x * parentSize.width,
          y * parentSize.height,
        ),
      PositionType.sequential => throw StateError(
          'Cannot convert sequential position to absolute without layout context. '
          'Use LayoutCalculator instead.',
        ),
      PositionType.fill => Offset.zero,
    };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocalPosition &&
        other.x == x &&
        other.y == y &&
        other.type == type &&
        other.proportionalValue == proportionalValue;
  }

  @override
  int get hashCode => Object.hash(x, y, type, proportionalValue);

  @override
  String toString() => 'LocalPosition(${type.name}: x=$x, y=$y${proportionalValue != null ? ", prop=$proportionalValue" : ""})';
}

/// Absolute position in world coordinates.
///
/// Global positions are independent of any Hook's local coordinate system.
/// They represent the final position in the overall UI layout.
///
/// ## Usage
///
/// ```dart
/// final globalPos = GlobalPosition(150.0, 300.0);
/// ```
@immutable
class GlobalPosition {
  /// Creates a global position at the given coordinates.
  const GlobalPosition(this.x, this.y);

  /// The x-coordinate in world coordinates (pixels).
  final double x;

  /// The y-coordinate in world coordinates (pixels).
  final double y;

  /// Converts to a Flutter [Offset].
  Offset toOffset() => Offset(x, y);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GlobalPosition && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'GlobalPosition(x=$x, y=$y)';
}

/// Type of positioning strategy for a [LocalPosition].
enum PositionType {
  /// Exact pixel coordinates relative to parent.
  absolute,

  /// Percentage (0.0-1.0) of parent size.
  proportional,

  /// Position in sequential flow (index).
  sequential,

  /// Fill all available space in parent.
  fill,
}

/// Utility class for coordinate system conversions.
///
/// Provides methods to convert between local and global coordinate systems
/// in the hierarchical Hook tree structure.
///
/// ## Coordinate Conversion
///
/// The coordinate system hierarchy works as follows:
///
/// 1. Each Hook has its own local coordinate system
/// 2. Child Hooks inherit and transform their parent's coordinate system
/// 3. Global position is the accumulation of all transformations
///
/// ## Example
///
/// ```dart
/// // Root Hook at (0, 0) with size (800, 600)
/// final root = UIHookNode.root();
///
/// // Child Hook at local position (100, 50) with size (200, 300)
/// final child = UIHookNode(
///   hookPointId: 'sidebar',
///   localPosition: LocalPosition.absolute(100, 50),
///   size: Size(200, 300),
/// );
/// root.addChild(child);
///
/// // Node at local position (10, 20) within child Hook
/// final nodeLocal = LocalPosition.absolute(10, 20);
///
/// // Convert to global: (100 + 10, 50 + 20) = (110, 70)
/// final nodeGlobal = CoordinateSystem.localToGlobal(child, nodeLocal);
/// ```
class CoordinateSystem {
  /// Converts a local position within a Hook to global coordinates.
  ///
  /// Traverses up the Hook tree, accumulating position transformations
  /// to compute the final world position.
  ///
  /// [hook] is the Hook containing the local position.
  /// [localPosition] is the position within the Hook's local coordinate system.
  ///
  /// Returns the equivalent global position.
  static GlobalPosition localToGlobal(
    UIHookNode hook,
    LocalPosition localPosition,
  ) {
    // Convert local position to absolute pixels
    final parentSize = hook.parent?.size ?? Size.infinite;
    final absoluteOffset = localPosition.toAbsolute(parentSize);

    // Accumulate positions up the tree
    var globalX = absoluteOffset.dx;
    var globalY = absoluteOffset.dy;

    UIHookNode? current = hook;
    while (current?.parent != null) {
      final parentLocalPos = current!.localPosition;
      final parentSize = current.parent!.size;

      // Convert parent's local position to absolute
      final parentAbsolute = parentLocalPos.toAbsolute(parentSize);
      globalX += parentAbsolute.dx;
      globalY += parentAbsolute.dy;

      current = current.parent;
    }

    return GlobalPosition(globalX, globalY);
  }

  /// Converts a global position to a local position within a Hook.
  ///
  /// Traverses up the Hook tree, subtracting parent transformations
  /// to compute the position relative to the target Hook.
  ///
  /// [hook] is the target Hook for the local coordinate system.
  /// [globalPosition] is the world position to convert.
  ///
  /// Returns the equivalent local position (always absolute type).
  static LocalPosition globalToLocal(
    UIHookNode hook,
    GlobalPosition globalPosition,
  ) {
    // Accumulate parent positions
    var parentOffsetX = 0.0;
    var parentOffsetY = 0.0;

    UIHookNode? current = hook;
    while (current?.parent != null) {
      final parentLocalPos = current!.localPosition;
      final parentSize = current.parent!.size;

      // Convert parent's local position to absolute
      final parentAbsolute = parentLocalPos.toAbsolute(parentSize);
      parentOffsetX += parentAbsolute.dx;
      parentOffsetY += parentAbsolute.dy;

      current = current.parent;
    }

    // Subtract parent offsets to get local position
    final localX = globalPosition.x - parentOffsetX;
    final localY = globalPosition.y - parentOffsetY;

    return LocalPosition.absolute(localX, localY);
  }

  /// Converts a local position from one Hook to another Hook's local space.
  ///
  /// This is useful when moving nodes between Hooks.
  ///
  /// [fromHook] is the source Hook.
  /// [toHook] is the target Hook.
  /// [localPosition] is the position in the source Hook's local space.
  ///
  /// Returns the equivalent position in the target Hook's local space.
  static LocalPosition convertBetweenHooks(
    UIHookNode fromHook,
    UIHookNode toHook,
    LocalPosition localPosition,
  ) {
    // Convert to global first
    final globalPos = localToGlobal(fromHook, localPosition);

    // Then convert to target Hook's local space
    return globalToLocal(toHook, globalPos);
  }

  /// Calculates the global bounds of a Hook.
  ///
  /// Returns the global position and size of the Hook in world coordinates.
  ///
  /// [hook] is the Hook to calculate bounds for.
  static Rect calculateGlobalBounds(UIHookNode hook) {
    final globalPos = _getHookGlobalPosition(hook);
    return Rect.fromLTWH(globalPos.x, globalPos.y, hook.size.width, hook.size.height);
  }

  /// Gets the global position of a Hook (origin).
  ///
  /// [hook] is the Hook to get the position for.
  static GlobalPosition _getHookGlobalPosition(UIHookNode hook) {
    var globalX = 0.0;
    var globalY = 0.0;

    UIHookNode? current = hook;
    while (current?.parent != null) {
      final parentLocalPos = current!.localPosition;
      final parentSize = current.parent!.size;

      // Convert current Hook's local position to absolute
      final absolutePos = parentLocalPos.toAbsolute(parentSize);
      globalX += absolutePos.dx;
      globalY += absolutePos.dy;

      current = current.parent;
    }

    return GlobalPosition(globalX, globalY);
  }

  /// Checks if a point in global coordinates is within a Hook's bounds.
  ///
  /// [hook] is the Hook to test.
  /// [globalPoint] is the global position to test.
  static bool containsPoint(UIHookNode hook, GlobalPosition globalPoint) {
    final bounds = calculateGlobalBounds(hook);
    return bounds.contains(globalPoint.toOffset());
  }
}
