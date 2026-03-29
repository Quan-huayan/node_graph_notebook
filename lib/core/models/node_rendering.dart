/// Node rendering capabilities for dual rendering system.
///
/// This module defines the rendering interface that allows Nodes to render
/// in both Flutter (Widget tree) and Flame (component tree) contexts.
///
/// ## Architecture
///
/// ```
/// Node
///   ├─ buildFlutterWidget() → Flutter Widget
///   └─ buildFlameComponent() → Flame Component
///
/// Position (stored in UILayoutService, not in Node)
///   └─ LocalPosition in NodeAttachment
/// ```
///
/// ## Design Philosophy
///
/// - **Nodes are autonomous**: They don't know where they are positioned
/// - **Position is external**: Managed by UILayoutService via NodeAttachment
/// - **Dual rendering**: Same Node can render in Flutter or Flame contexts
/// - **State preservation**: Node state independent of rendering context
///
/// ## Usage
///
/// ```dart
/// class MyNode extends Node with NodeRendering {
///   @override
///   Widget buildFlutterWidget(BuildContext context) {
///     return MyNodeWidget(node: this);
///   }
///
///   @override
///   Component buildFlameComponent(GraphWorld world) {
///     return MyNodeComponent(node: this);
///   }
/// }
/// ```
library;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/widgets.dart';

import 'node.dart';

/// Mixin that adds dual rendering capabilities to Node.
///
/// This mixin provides the interface for Nodes to render themselves
/// in both Flutter and Flame contexts.
///
/// ## Implementation Guide
///
/// When mixing this into Node, implement both rendering methods:
///
/// ```dart
/// class TextNode extends Node with NodeRendering {
///   TextNode({
///     required super.id,
///     required super.title,
///     super.content,
///   }) : super(
///           references: const {},
///           position: Offset.zero, // Will be removed in Phase 6
///           size: const Size(200, 100),
///           viewMode: NodeViewMode.compact,
///           createdAt: DateTime.now(),
///           updatedAt: DateTime.now(),
///           metadata: const {},
///         );
///
///   @override
///   Widget buildFlutterWidget(BuildContext context) {
///     return Container(
///       padding: const EdgeInsets.all(8),
///       child: Text(title),
///     );
///   }
///
///   @override
///   Component buildFlameComponent(GraphWorld world) {
///     return TextNodeComponent(node: this);
///   }
/// }
/// ```
///
/// ## Flutter Widget Rendering
///
/// The `buildFlutterWidget()` method should return a Flutter Widget that
/// represents this Node in a Flutter context (e.g., in Sidebar, Toolbar).
///
/// Guidelines:
/// - Use `this` to access Node properties (title, content, metadata)
/// - Don't assume any position (position is managed by UILayoutService)
/// - Keep widgets simple and efficient
/// - Use const constructors where possible
///
/// ## Flame Component Rendering
///
/// The `buildFlameComponent()` method should return a Flame Component that
/// represents this Node in a Flame context (e.g., in Graph).
///
/// Guidelines:
/// - Use `this` to access Node properties
/// - Components will be positioned by UILayoutService
/// - Implement interaction handling (tap, drag, etc.)
/// - Cache resources (Paint, TextPainter) for performance
mixin NodeRendering on Node {
  /// Builds a Flutter Widget representation of this Node.
  ///
  /// This method is called when the Node needs to be rendered in a
  /// Flutter context (e.g., Sidebar, Toolbar, Settings).
  ///
  /// [context] is the Flutter BuildContext.
  ///
  /// Returns a Widget that represents this Node.
  ///
  /// ## Example
  ///
  /// ```dart
  /// @override
  /// Widget buildFlutterWidget(BuildContext context) {
  ///   return Card(
  ///     child: Padding(
  ///       padding: const EdgeInsets.all(8.0),
  ///       child: Column(
  ///         crossAxisAlignment: CrossAxisAlignment.start,
  ///         children: [
  ///           Text(
  ///             title,
  ///             style: Theme.of(context).textTheme.titleMedium,
  ///           ),
  ///           if (content != null)
  ///             Text(
  ///               content!,
  ///               maxLines: 3,
  ///               overflow: TextOverflow.ellipsis,
  ///             ),
  ///         ],
  ///       ),
  ///     ),
  ///   );
  /// }
  /// ```
  Widget buildFlutterWidget(BuildContext context);

  /// Builds a Flame Component representation of this Node.
  ///
  /// This method is called when the Node needs to be rendered in a
  /// Flame context (e.g., in Graph visualization).
  ///
  /// [world] is the GraphWorld (Flame game world) instance.
  ///
  /// Returns a Component that represents this Node.
  ///
  /// ## Example
  ///
  /// ```dart
  /// @override
  /// Component buildFlameComponent(GraphWorld world) {
  ///   return NodeComponent()
  ///     ..node = this
  ///     ..size = size.toVector2();
  /// }
  /// ```
  ///
  /// ## Performance Tips
  ///
  /// - Cache Paint objects (don't create in render method)
  /// - Cache TextPainter objects for text rendering
  /// - Use PositionComponent with size for hit testing
  /// - Implement onTap, onDrag, etc. for interactions
  Component buildFlameComponent(dynamic world);

  /// Gets the preferred size for rendering in Flutter.
  ///
  /// This is a hint for the layout system. The actual size may be
  /// adjusted by the Hook's layout strategy.
  ///
  /// Returns the preferred size, or null if no preference.
  Size get preferredFlutterSize => size;

  /// Gets the preferred size for rendering in Flame.
  ///
  /// This is a hint for the layout system. The actual size may be
  /// adjusted by the Hook's layout strategy.
  ///
  /// Returns the preferred size, or null if no preference.
  Size get preferredFlameSize => size;

  /// Checks if this Node can render in Flutter context.
  ///
  /// Returns true if the Node has a Flutter widget representation.
  /// Override this to return false if the Node only supports Flame.
  bool get canRenderInFlutter => true;

  /// Checks if this Node can render in Flame context.
  ///
  /// Returns true if the Node has a Flame component representation.
  /// Override this to return false if the Node only supports Flutter.
  bool get canRenderInFlame => true;

  /// Validates that this Node can render in the given context.
  ///
  /// Throws [StateError] if the Node cannot render in the requested context.
  ///
  /// [isFlutter] is true for Flutter context, false for Flame.
  void validateRendering(bool isFlutter) {
    if (isFlutter && !canRenderInFlutter) {
      throw StateError(
        'Node $id cannot render in Flutter context. '
        'Implement buildFlutterWidget() or set canRenderInFlutter to true.',
      );
    }
    if (!isFlutter && !canRenderInFlame) {
      throw StateError(
        'Node $id cannot render in Flame context. '
        'Implement buildFlameComponent() or set canRenderInFlame to true.',
      );
    }
  }
}

/// Default implementation of NodeRendering for basic Nodes.
///
/// This provides simple placeholder widgets/components for Nodes
/// that don't have custom rendering logic.
///
/// Plugins can mix this into their Node classes for a quick start.
///
/// ## Example
///
/// ```dart
/// class SimpleNode extends Node with DefaultNodeRendering {
///   SimpleNode({
///     required super.id,
///     required super.title,
///   }) : super(
///           references: const {},
///           position: Offset.zero,
///           size: const Size(150, 80),
///           viewMode: NodeViewMode.compact,
///           createdAt: DateTime.now(),
///           updatedAt: DateTime.now(),
///           metadata: const {},
///         );
/// }
/// ```
mixin DefaultNodeRendering on Node implements NodeRendering {
  @override
  Widget buildFlutterWidget(BuildContext context) => Container(
      width: preferredFlutterSize.width.isFinite ? preferredFlutterSize.width : 150,
      height: preferredFlutterSize.height.isFinite ? preferredFlutterSize.height : 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color != null ? Color(int.parse(color!)) : null,
        border: Border.all(color: const Color(0xFFCCCCCC)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (content != null)
            Expanded(
              child: Text(
                content!,
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );

  @override
  Component buildFlameComponent(dynamic world) {
    // Return a basic placeholder component
    // In a real implementation, this would return a proper Flame component
    return _PlaceholderNodeComponent(node: this);
  }
}

/// Placeholder Flame component for Nodes without custom rendering.
class _PlaceholderNodeComponent extends Component {
  _PlaceholderNodeComponent({required this.node});

  final Node node;

  @override
  String toString() => 'PlaceholderNodeComponent(${node.id})';
}

/// Extension to convert Flutter Size to Flame Vector2.
extension SizeToVector2 on Size {
  /// Converts this Size to a Flame Vector2.
  Vector2 toVector2() => Vector2(width, height);
}
