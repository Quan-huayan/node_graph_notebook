/// Base renderer interface for UI layout system.
///
/// Defines the contract for renderers that map the Hook tree to
/// different rendering frameworks (Flutter, Flame, etc.).
library;

import '../node_attachment.dart';
import '../ui_hook_tree.dart';

/// Base interface for rendering Hook trees.
///
/// Renderers are responsible for converting the hierarchical Hook tree
/// into framework-specific rendering output (Flutter Widgets, Flame components, etc.).
///
/// ## Implementing a Custom Renderer
///
/// ```dart
/// class MyCustomRenderer extends RendererBase<Widget> {
///   @override
///   Widget render(UIHookNode hook, Map<String, dynamic> context) {
///     // Convert Hook tree to Widget
///     return Container(
///       child: Column(
///         children: [
///           ...hook.children.map((child) => render(child, context)),
///           ...hook.attachedNodes.values.map((attachment) =>
///             renderAttachedNode(attachment, context),
///           ),
///         ],
///       ),
///     );
///   }
///
///   @override
///   Widget renderAttachedNode(NodeAttachment attachment, Map<String, dynamic> context) {
///     // Render attached Node
///     return NodeWidget(nodeId: attachment.nodeId);
///   }
/// }
/// ```
abstract class RendererBase<T> {
  /// Renders a Hook tree to framework-specific output.
  ///
  /// [hook] is the Hook to render.
  /// [context] is the rendering context (framework-specific).
  ///
  /// Returns the rendered output (e.g., Flutter Widget, Flame Component).
  T render(UIHookNode hook, Map<String, dynamic> context);

  /// Renders an attached Node.
  ///
  /// [attachment] is the Node attachment to render.
  /// [context] is the rendering context (framework-specific).
  ///
  /// Returns the rendered output for the Node.
  T renderAttachedNode(NodeAttachment attachment, Map<String, dynamic> context);

  /// Gets the framework-specific type name for debugging.
  String get outputTypeName;
}
