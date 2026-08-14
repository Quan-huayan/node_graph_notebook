library;

import 'package:flutter/material.dart';
import 'ui_hook_tree.dart';

/// A position defined relative to a parent container, supporting multiple
/// coordinate modes (absolute, proportional, sequential, fill).
@immutable
class LocalPosition {
  /// Creates an absolute position with pixel coordinates.
  const LocalPosition.absolute(this.x, this.y)
      : type = PositionType.absolute,
        proportionalValue = null;

  /// Creates a proportional position as a fraction of the parent size.
  const LocalPosition.proportional(this.x, this.y)
      : type = PositionType.proportional,
        proportionalValue = null;

  /// Creates a sequential position determined by the child index.
  LocalPosition.sequential({required int index})
      : x = index.toDouble(),
        y = 0.0,
        type = PositionType.sequential,
        proportionalValue = null;

  /// Creates a fill position that occupies the entire parent container.
  const LocalPosition.fill()
      : x = 0.0,
        y = 0.0,
        type = PositionType.fill,
        proportionalValue = null;

  /// The x coordinate (in pixels for absolute, fraction for proportional).
  final double x;

  /// The y coordinate (in pixels for absolute, fraction for proportional).
  final double y;

  /// The positioning mode.
  final PositionType type;

  /// Optional proportional value for custom scaling calculations.
  final double? proportionalValue;

  /// Converts this local position to an absolute [Offset] within the given
  /// [parentSize], based on the current [PositionType].
  Offset toAbsolute(Size parentSize) => switch (type) {
      PositionType.absolute => Offset(x, y),
      PositionType.proportional => Offset(
          x * parentSize.width,
          y * parentSize.height,
        ),
      PositionType.sequential => throw StateError(
          'Cannot convert sequential position to absolute without layout context.',
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

/// A screen-space (global) position defined by absolute x/y coordinates,
/// independent of any parent container.
@immutable
class GlobalPosition {
  /// Creates a [GlobalPosition] with the given absolute screen-space coordinates.
  const GlobalPosition(this.x, this.y);

  /// The x coordinate in screen-space pixels.
  final double x;

  /// The y coordinate in screen-space pixels.
  final double y;

  /// Converts this global position to a Flutter [Offset].
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

/// The type of coordinate system used for a position.
enum PositionType {
  /// Pixel-based absolute coordinates.
  absolute,

  /// Fractional coordinates relative to parent size (0.0 to 1.0).
  proportional,

  /// Index-based sequential ordering within the parent.
  sequential,

  /// Fills the entire parent container.
  fill,
}

/// Utility class providing coordinate transformations between local and global
/// spaces within the hook tree.
class CoordinateSystem {
  /// Converts a [localPosition] in [hook]'s local space to a [GlobalPosition]
  /// by walking up the parent chain and accumulating offsets.
  static GlobalPosition localToGlobal(
    UIHookNode hook,
    LocalPosition localPosition,
  ) {
    final parentSize = hook.parent?.size ?? Size.infinite;
    final absoluteOffset = localPosition.toAbsolute(parentSize);

    var globalX = absoluteOffset.dx;
    var globalY = absoluteOffset.dy;

    UIHookNode? current = hook;
    while (current?.parent != null) {
      final parentLocalPos = current!.localPosition;
      final parentSize = current.parent!.size;

      final parentAbsolute = parentLocalPos.toAbsolute(parentSize);
      globalX += parentAbsolute.dx;
      globalY += parentAbsolute.dy;

      current = current.parent;
    }

    return GlobalPosition(globalX, globalY);
  }

  /// Converts a [globalPosition] in screen space back to a local position
  /// relative to [hook], by subtracting accumulated parent offsets.
  static LocalPosition globalToLocal(
    UIHookNode hook,
    GlobalPosition globalPosition,
  ) {
    var parentOffsetX = 0.0;
    var parentOffsetY = 0.0;

    UIHookNode? current = hook;
    while (current?.parent != null) {
      final parentLocalPos = current!.localPosition;
      final parentSize = current.parent!.size;

      final parentAbsolute = parentLocalPos.toAbsolute(parentSize);
      parentOffsetX += parentAbsolute.dx;
      parentOffsetY += parentAbsolute.dy;

      current = current.parent;
    }

    final localX = globalPosition.x - parentOffsetX;
    final localY = globalPosition.y - parentOffsetY;

    return LocalPosition.absolute(localX, localY);
  }

  /// Converts a [localPosition] from [fromHook]'s coordinate space to
  /// [toHook]'s coordinate space via the global coordinate system.
  static LocalPosition convertBetweenHooks(
    UIHookNode fromHook,
    UIHookNode toHook,
    LocalPosition localPosition,
  ) {
    final globalPos = localToGlobal(fromHook, localPosition);

    return globalToLocal(toHook, globalPos);
  }

  /// Calculates the global bounding rectangle of [hook] in screen space.
  static Rect calculateGlobalBounds(UIHookNode hook) {
    final globalPos = _getHookGlobalPosition(hook);
    return Rect.fromLTWH(globalPos.x, globalPos.y, hook.size.width, hook.size.height);
  }

  static GlobalPosition _getHookGlobalPosition(UIHookNode hook) {
    var globalX = 0.0;
    var globalY = 0.0;

    UIHookNode? current = hook;
    while (current?.parent != null) {
      final parentLocalPos = current!.localPosition;
      final parentSize = current.parent!.size;

      final absolutePos = parentLocalPos.toAbsolute(parentSize);
      globalX += absolutePos.dx;
      globalY += absolutePos.dy;

      current = current.parent;
    }

    return GlobalPosition(globalX, globalY);
  }

  /// Returns true if [globalPoint] falls within [hook]'s global bounding rect.
  static bool containsPoint(UIHookNode hook, GlobalPosition globalPoint) {
    final bounds = calculateGlobalBounds(hook);
    return bounds.contains(globalPoint.toOffset());
  }
}