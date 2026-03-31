/// Flutter renderer for UI layout system.
///
/// Maps the Hook tree to Flutter Widget tree, supporting all layout strategies.
///
/// ## Architecture
///
/// ```
/// UIHookNode (Hook tree)
///     ↓
/// FlutterRenderer.render()
///     ↓
/// Widget tree (Container, Column, Row, Stack, Wrap, etc.)
///     ↓
/// Flutter renders to screen
/// ```
///
/// ## Usage
///
/// ```dart
/// final renderer = const FlutterRenderer();
/// final sidebarHook = layoutService.getHook('sidebar');
///
/// if (sidebarHook != null) {
///   final widget = renderer.render(
///     sidebarHook,
///     {'buildContext': context},
///   );
///
///   return widget;
/// }
/// ```
library;

import 'package:flutter/material.dart';
import '../layout_strategy.dart';
import '../node_attachment.dart';
import '../ui_hook_tree.dart';
import 'renderer_base.dart';

/// Renderer that maps Hook tree to Flutter Widget tree.
///
/// Supports all built-in layout strategies:
/// - **absolute**: Stack with Positioned children
/// - **sequential**: Column (vertical) or Row (horizontal)
/// - **proportional**: Column/Row with Flexible children
/// - **flow**: Wrap widget
/// - **grid**: GridView or custom grid layout
class FlutterRenderer extends RendererBase<Widget> {
  /// Creates a Flutter renderer.
  ///
  /// [nodeWidgetBuilder] is optional custom builder for Nodes.
  /// If not provided, uses a default placeholder widget.
  FlutterRenderer({
    this.nodeWidgetBuilder,
  });

  /// Custom builder for Node widgets.
  ///
  /// If provided, this builder is called for each attached Node
  /// to create the Flutter Widget for that Node.
  ///
  /// Parameters:
  /// - `nodeId`: The ID of the Node to render.
  /// - `attachment`: The Node's attachment info.
  /// - `context`: The BuildContext from Flutter.
  final Widget Function(String nodeId, NodeAttachment attachment, BuildContext context)?
      nodeWidgetBuilder;

  @override
  String get outputTypeName => 'Widget';

  @override
  Widget render(UIHookNode hook, Map<String, dynamic> context) {
    final buildContext = context['buildContext'] as BuildContext?;

    // Get layout strategy
    final strategy = hook.layoutConfig.strategy;

    // Render based on strategy
    return switch (strategy) {
      LayoutStrategy.absolute => _renderAbsolute(hook, buildContext),
      LayoutStrategy.sequential => _renderSequential(hook, buildContext),
      LayoutStrategy.proportional => _renderProportional(hook, buildContext),
      LayoutStrategy.flow => _renderFlow(hook, buildContext),
      LayoutStrategy.grid => _renderGrid(hook, buildContext),
      LayoutStrategy.custom => _renderCustom(hook, buildContext),
    };
  }

  @override
  Widget renderAttachedNode(
    NodeAttachment attachment,
    Map<String, dynamic> context,
  ) {
    final buildContext = context['buildContext'] as BuildContext?;

    if (nodeWidgetBuilder != null) {
      return nodeWidgetBuilder!(attachment.nodeId, attachment, buildContext!);
    }

    // Default placeholder widget
    return _DefaultNodeWidget(
      nodeId: attachment.nodeId,
      attachment: attachment,
    );
  }

  /// Renders absolute layout (Stack with Positioned children).
  Widget _renderAbsolute(UIHookNode hook, BuildContext? context) {
    final children = <Widget>[];

    // Add child Hooks
    for (final child in hook.children) {
      final childWidget = render(child, {'buildContext': context});

      // Convert to absolute offset
      final offset = _calculateChildOffset(child, hook.size);

      children.add(
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: SizedBox(
            width: child.size.width.isFinite ? child.size.width : null,
            height: child.size.height.isFinite ? child.size.height : null,
            child: childWidget,
          ),
        ),
      );
    }

    // Add attached Nodes
    for (final attachment in hook.attachedNodes.values) {
      final nodeWidget = renderAttachedNode(
        attachment,
        {'buildContext': context},
      );
      final offset = _calculateNodeOffset(attachment, hook.size);

      children.add(
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: nodeWidget,
        ),
      );
    }

    return SizedBox(
      width: hook.size.width.isFinite ? hook.size.width : null,
      height: hook.size.height.isFinite ? hook.size.height : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: children,
      ),
    );
  }

  /// Renders sequential layout (Column or Row).
  Widget _renderSequential(UIHookNode hook, BuildContext? context) {
    final isVertical = hook.layoutConfig.direction == Axis.vertical;
    final config = hook.layoutConfig;

    final children = <Widget>[];

    // Add child Hooks
    for (final child in hook.children) {
      final childWidget = render(child, {'buildContext': context});
      children.add(
        SizedBox(
          width: child.size.width.isFinite && !isVertical ? child.size.width : null,
          height: child.size.height.isFinite && isVertical ? child.size.height : null,
          child: childWidget,
        ),
      );
    }

    // Add attached Nodes
    final nodeWidgets = <Widget>[];
    for (final attachment in hook.attachedNodes.values) {
      final nodeWidget = renderAttachedNode(
        attachment,
        {'buildContext': context},
      );
      nodeWidgets.add(nodeWidget);
    }

    // Combine children and Nodes
    final allChildren = [
      ...children,
      ...nodeWidgets,
    ];

    // Apply padding
    final paddedChildren = config.padding != EdgeInsets.zero
        ? [
            Padding(
              padding: config.padding,
              child: isVertical
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _addSpacing(allChildren, config.spacing, isVertical),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _addSpacing(allChildren, config.spacing, isVertical),
                    ),
            )
          ]
        : isVertical
            ? [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _addSpacing(allChildren, config.spacing, isVertical),
                )
              ]
            : [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _addSpacing(allChildren, config.spacing, isVertical),
                )
              ];

    return SizedBox(
      width: hook.size.width.isFinite ? hook.size.width : null,
      height: hook.size.height.isFinite ? hook.size.height : null,
      child: paddedChildren.length == 1
          ? paddedChildren[0]
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: paddedChildren,
            ),
    );
  }

  /// Renders proportional layout (Column/Row with Flexible children).
  Widget _renderProportional(UIHookNode hook, BuildContext? context) =>
    // Similar to sequential but with Flexible/Expanded
    // Implementation deferred - can be added as needed
    _renderSequential(hook, context);

  /// Renders flow layout (Wrap widget).
  Widget _renderFlow(UIHookNode hook, BuildContext? context) {
    final config = hook.layoutConfig;
    final children = <Widget>[];

    // Add child Hooks
    for (final child in hook.children) {
      final childWidget = render(child, {'buildContext': context});
      children.add(
        SizedBox(
          width: child.size.width.isFinite ? child.size.width : null,
          height: child.size.height.isFinite ? child.size.height : null,
          child: childWidget,
        ),
      );
    }

    // Add attached Nodes
    for (final attachment in hook.attachedNodes.values) {
      final nodeWidget = renderAttachedNode(
        attachment,
        {'buildContext': context},
      );
      children.add(nodeWidget);
    }

    return Container(
      width: hook.size.width.isFinite ? hook.size.width : null,
      height: hook.size.height.isFinite ? hook.size.height : null,
      padding: config.padding,
      child: Wrap(
        direction: config.direction,
        spacing: config.spacing,
        runSpacing: config.crossAxisSpacing,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: children,
      ),
    );
  }

  /// Renders grid layout.
  Widget _renderGrid(UIHookNode hook, BuildContext? context) {
    final config = hook.layoutConfig;
    final columns = config.columns ?? 2;

    final children = <Widget>[];

    // Add child Hooks
    for (final child in hook.children) {
      final childWidget = render(child, {'buildContext': context});
      children.add(childWidget);
    }

    // Add attached Nodes
    for (final attachment in hook.attachedNodes.values) {
      final nodeWidget = renderAttachedNode(
        attachment,
        {'buildContext': context},
      );
      children.add(nodeWidget);
    }

    return Container(
      width: hook.size.width.isFinite ? hook.size.width : null,
      height: hook.size.height.isFinite ? hook.size.height : null,
      padding: config.padding,
      child: GridView.count(
        crossAxisCount: columns,
        mainAxisSpacing: config.spacing,
        crossAxisSpacing: config.crossAxisSpacing,
        shrinkWrap: true,
        children: children,
      ),
    );
  }

  /// Renders custom layout using custom calculator.
  Widget _renderCustom(UIHookNode hook, BuildContext? context) {
    // Use custom calculator to determine positions, then render as absolute
    final calculator = hook.layoutConfig.customCalculator;
    if (calculator == null) {
      return _renderSequential(hook, context);
    }

    final result = calculator.calculate(hook);
    return _renderFromResult(hook, result, context);
  }

  /// Renders layout from pre-calculated result.
  Widget _renderFromResult(
    UIHookNode hook,
    LayoutResult result,
    BuildContext? context,
  ) {
    final children = <Widget>[];

    // Add child Hooks
    for (final child in hook.children) {
      final position = result.positions[child.id];
      if (position == null) continue;

      final childWidget = render(child, {'buildContext': context});
      final offset = position.toAbsolute(hook.size);

      children.add(
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: childWidget,
        ),
      );
    }

    // Add attached Nodes
    for (final attachment in hook.attachedNodes.values) {
      final position = result.positions[attachment.nodeId];
      if (position == null) continue;

      final nodeWidget = renderAttachedNode(
        attachment,
        {'buildContext': context},
      );
      final offset = position.toAbsolute(hook.size);

      children.add(
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: nodeWidget,
        ),
      );
    }

    return SizedBox(
      width: hook.size.width.isFinite ? hook.size.width : null,
      height: hook.size.height.isFinite ? hook.size.height : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: children,
      ),
    );
  }

  /// Calculates offset for a child Hook within parent.
  Offset _calculateChildOffset(UIHookNode child, Size parentSize) => child.localPosition.toAbsolute(parentSize);

  /// Calculates offset for an attached Node within Hook.
  Offset _calculateNodeOffset(NodeAttachment attachment, Size hookSize) => attachment.localPosition.toAbsolute(hookSize);

  /// Adds spacing widgets between children.
  List<Widget> _addSpacing(List<Widget> children, double spacing, bool isVertical) {
    if (children.isEmpty) return children;
    if (spacing <= 0) return children;

    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(
          SizedBox(
            width: isVertical ? 0 : spacing,
            height: isVertical ? spacing : 0,
          ),
        );
      }
    }
    return result;
  }
}

/// Default placeholder widget for Nodes.
class _DefaultNodeWidget extends StatelessWidget {
  const _DefaultNodeWidget({
    required this.nodeId,
    required this.attachment,
  });

  final String nodeId;
  final NodeAttachment attachment;

  @override
  Widget build(BuildContext context) => Container(
      width: attachment.size?.width ?? 100,
      height: attachment.size?.height ?? 50,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          'Node: $nodeId',
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
}
