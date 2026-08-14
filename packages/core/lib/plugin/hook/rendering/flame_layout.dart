library;

import 'package:flutter/material.dart';
import '../coordinate_system.dart';

/// Defines the type of layout algorithm used for arranging Flame hook children.
enum FlameLayoutType {
  /// Each child is placed at its explicit absolute position.
  absolute,

  /// Children are arranged one after another along the configured axis.
  sequential,

  /// Children flow like a word-wrap, breaking into a new row/column when the
  /// cross-axis boundary is reached.
  flow,

  /// Children are placed in a fixed-column grid.
  grid,
}

/// Configuration for a flame layout calculation, specifying the algorithm type,
/// axis direction, spacing, padding, and optional column count.
class FlameLayoutConfig {
  /// Creates a [FlameLayoutConfig] with the given parameters.
  const FlameLayoutConfig({
    required this.type,
    this.direction = Axis.vertical,
    this.spacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.padding = EdgeInsets.zero,
    this.columns,
  });

  /// The layout algorithm type.
  final FlameLayoutType type;

  /// The primary axis direction for sequential/flow layouts.
  final Axis direction;

  /// Spacing between items along the primary axis.
  final double spacing;

  /// Spacing between items along the cross axis (used in flow/grid layouts).
  final double crossAxisSpacing;

  /// Padding around the layout area.
  final EdgeInsets padding;

  /// Optional fixed number of columns (used in grid layout).
  final int? columns;

  /// Returns a copy of this config with the given fields replaced.
  FlameLayoutConfig copyWith({
    FlameLayoutType? type,
    Axis? direction,
    double? spacing,
    double? crossAxisSpacing,
    EdgeInsets? padding,
    int? columns,
  }) => FlameLayoutConfig(
      type: type ?? this.type,
      direction: direction ?? this.direction,
      spacing: spacing ?? this.spacing,
      crossAxisSpacing: crossAxisSpacing ?? this.crossAxisSpacing,
      padding: padding ?? this.padding,
      columns: columns ?? this.columns,
    );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FlameLayoutConfig &&
        other.type == type &&
        other.direction == direction &&
        other.spacing == spacing &&
        other.crossAxisSpacing == crossAxisSpacing &&
        other.padding == padding &&
        other.columns == columns;
  }

  @override
  int get hashCode => Object.hash(
        type,
        direction,
        spacing,
        crossAxisSpacing,
        padding,
        columns,
      );

  @override
  String toString() => 'FlameLayoutConfig(type: $type, direction: $direction, spacing: $spacing)';
}

/// The result of a layout calculation, containing per-item positions and the
/// total required size.
class FlameLayoutResult {
  /// Creates a [FlameLayoutResult] with the given positions and total size.
  const FlameLayoutResult({
    required this.positions,
    required this.totalSize,
  });

  /// Map from item IDs to their computed [Offset] positions.
  final Map<String, Offset> positions;

  /// The total size required by the layout.
  final Size totalSize;
}

/// Defines the interface for calculating positions of layout items within a
/// container.
abstract class FlameLayoutCalculator {
  /// Calculates positions for the given [items] within [containerSize] using
  /// the provided [config].
  FlameLayoutResult calculate(List<FlameLayoutItem> items, Size containerSize, FlameLayoutConfig config);
}

/// Represents an item to be laid out, with an identifier, size, and local
/// position.
class FlameLayoutItem {
  /// Creates a [FlameLayoutItem] with the given properties.
  const FlameLayoutItem({
    required this.id,
    required this.size,
    required this.localPosition,
  });

  /// Unique identifier for this item.
  final String id;

  /// The size of the item.
  final Size size;

  /// The local position hint for this item.
  final LocalPosition localPosition;
}

/// Arranges children sequentially (one after another) along the configured
/// axis.
class FlameSequentialCalculator implements FlameLayoutCalculator {
  @override
  FlameLayoutResult calculate(List<FlameLayoutItem> items, Size containerSize, FlameLayoutConfig config) {
    final positions = <String, Offset>{};
    final isVertical = config.direction == Axis.vertical;

    var primaryPos = isVertical ? config.padding.top : config.padding.left;
    final secondaryPos = isVertical ? config.padding.left : config.padding.top;

    for (final item in items) {
      final position = isVertical
          ? Offset(secondaryPos, primaryPos)
          : Offset(primaryPos, secondaryPos);

      positions[item.id] = position;

      primaryPos += isVertical ? item.size.height : item.size.width;
      primaryPos += config.spacing;
    }

    final primaryAxisSize = primaryPos +
        (isVertical ? config.padding.bottom : config.padding.right);

    final totalSize = isVertical
        ? Size(containerSize.width, primaryAxisSize)
        : Size(primaryAxisSize, containerSize.height);

    return FlameLayoutResult(positions: positions, totalSize: totalSize);
  }
}

/// Places each child at its explicit absolute position, converting local
/// positions to absolute offsets within the container.
class FlameAbsoluteCalculator implements FlameLayoutCalculator {
  @override
  FlameLayoutResult calculate(List<FlameLayoutItem> items, Size containerSize, FlameLayoutConfig config) {
    final positions = <String, Offset>{};

    for (final item in items) {
      positions[item.id] = item.localPosition.toAbsolute(containerSize);
    }

    return FlameLayoutResult(positions: positions, totalSize: containerSize);
  }
}

/// Arranges children in a flowing manner, wrapping to the next row/column
/// when the cross-axis boundary is exceeded.
class FlameFlowCalculator implements FlameLayoutCalculator {
  @override
  FlameLayoutResult calculate(List<FlameLayoutItem> items, Size containerSize, FlameLayoutConfig config) {
    final positions = <String, Offset>{};
    final isVertical = config.direction == Axis.vertical;

    var primaryPos = isVertical ? config.padding.top : config.padding.left;
    var secondaryPos = isVertical ? config.padding.left : config.padding.top;
    var currentSecondaryLineSize = 0.0;

    final maxSecondaryWithPadding = (isVertical ? containerSize.width : containerSize.height) -
        (isVertical ? config.padding.horizontal : config.padding.vertical);

    for (final item in items) {
      final itemCrossSize = isVertical ? item.size.width : item.size.height;

      if (currentSecondaryLineSize + itemCrossSize > maxSecondaryWithPadding &&
          currentSecondaryLineSize > 0) {
        primaryPos += isVertical ? item.size.height : item.size.width;
        primaryPos += config.spacing;
        secondaryPos = isVertical ? config.padding.left : config.padding.top;
        currentSecondaryLineSize = 0;
      }

      final position = isVertical
          ? Offset(secondaryPos, primaryPos)
          : Offset(primaryPos, secondaryPos);

      positions[item.id] = position;

      secondaryPos += itemCrossSize;
      secondaryPos += config.crossAxisSpacing;
      currentSecondaryLineSize += itemCrossSize;
    }

    return FlameLayoutResult(positions: positions, totalSize: containerSize);
  }
}

/// Places children in a fixed-column grid layout, using the configured column
/// count (defaults to 2).
class FlameGridCalculator implements FlameLayoutCalculator {
  @override
  FlameLayoutResult calculate(List<FlameLayoutItem> items, Size containerSize, FlameLayoutConfig config) {
    final positions = <String, Offset>{};
    final columns = config.columns ?? 2;
    final columnCount = columns > 0 ? columns : 2;

    final availableWidth = containerSize.width - config.padding.horizontal;
    final cellWidth = (availableWidth - (columnCount - 1) * config.crossAxisSpacing) / columnCount;

    var col = 0;
    var currentY = config.padding.top;
    var maxRowHeight = 0.0;

    for (final item in items) {
      final x = config.padding.left + col * (cellWidth + config.crossAxisSpacing);
      final y = currentY;

      positions[item.id] = Offset(x, y);

      if (item.size.height > maxRowHeight) {
        maxRowHeight = item.size.height;
      }

      col++;
      if (col >= columnCount) {
        col = 0;
        currentY += maxRowHeight + config.spacing;
        maxRowHeight = 0.0;
      }
    }

    final totalHeight = currentY + maxRowHeight + config.padding.bottom;

    return FlameLayoutResult(
      positions: positions,
      totalSize: Size(containerSize.width, totalHeight),
    );
  }
}

/// Registry that maps [FlameLayoutType] values to their corresponding
/// [FlameLayoutCalculator] implementations.
class FlameLayoutCalculatorRegistry {
  /// Creates a [FlameLayoutCalculatorRegistry] and registers the built-in
  /// calculators for all layout types.
  FlameLayoutCalculatorRegistry() {
    _calculators[FlameLayoutType.absolute] = FlameAbsoluteCalculator();
    _calculators[FlameLayoutType.sequential] = FlameSequentialCalculator();
    _calculators[FlameLayoutType.flow] = FlameFlowCalculator();
    _calculators[FlameLayoutType.grid] = FlameGridCalculator();
  }

  final Map<FlameLayoutType, FlameLayoutCalculator> _calculators = {};

  /// Returns the calculator registered for the given [type], or null.
  FlameLayoutCalculator? getCalculator(FlameLayoutType type) => _calculators[type];

  /// Runs the appropriate calculator for [config]'s type on the given [items]
  /// within [containerSize].
  FlameLayoutResult calculate(List<FlameLayoutItem> items, Size containerSize, FlameLayoutConfig config) {
    final calculator = _calculators[config.type];
    if (calculator == null) {
      return FlameLayoutResult(positions: {}, totalSize: containerSize);
    }
    return calculator.calculate(items, containerSize, config);
  }
}