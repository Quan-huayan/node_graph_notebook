library;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../node_attachment.dart';
import '../ui_hook_tree.dart';
import 'flame_layout.dart';
import 'renderer_base.dart';

/// Thin alias for the Flame [World] type.
typedef FlameGameWorld = World;

/// Thin alias for the Flame [Component] type.
typedef FlameComponent = Component;

/// A [RendererBase] implementation that produces Flame [Component] trees from
/// the UI hook tree, using configurable layout calculators.
class FlameRenderer extends RendererBase<FlameComponent> {
  /// Creates a [FlameRenderer] with optional node component builder and layout
  /// config provider.
  FlameRenderer({
    this.nodeComponentBuilder,
    this.layoutConfigProvider,
  });

  /// Optional builder for custom Flame components per attached node.
  final FlameComponent Function(
    String nodeId,
    NodeAttachment attachment,
    Map<String, dynamic> context,
  )? nodeComponentBuilder;

  /// Optional provider that returns a [FlameLayoutConfig] for a given hook.
  final FlameLayoutConfig Function(UIHookNode hook)? layoutConfigProvider;

  final FlameLayoutCalculatorRegistry _calculatorRegistry = FlameLayoutCalculatorRegistry();

  @override
  String get outputTypeName => 'Component';

  @override
  FlameComponent render(UIHookNode hook, Map<String, dynamic> context) {
    final gameWorld = context['gameWorld'] as FlameGameWorld?;
    final config = layoutConfigProvider?.call(hook) ?? const FlameLayoutConfig(type: FlameLayoutType.absolute);

    final items = _buildLayoutItems(hook, context);
    final result = _calculatorRegistry.calculate(items, hook.size, config);

    return _buildContainer(hook, result, context, gameWorld);
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

    return _DefaultNodeComponent(
      nodeId: attachment.nodeId,
      attachment: attachment,
    );
  }

  List<FlameLayoutItem> _buildLayoutItems(UIHookNode hook, Map<String, dynamic> context) {
    final items = <FlameLayoutItem>[];

    for (final child in hook.children) {
      items.add(FlameLayoutItem(
        id: child.id,
        size: child.size,
        localPosition: child.localPosition,
      ));
    }

    for (final attachment in hook.attachedNodes.values) {
      items.add(FlameLayoutItem(
        id: attachment.nodeId,
        size: attachment.size ?? const Size(100, 50),
        localPosition: attachment.localPosition,
      ));
    }

    return items;
  }

  FlameComponent _buildContainer(
    UIHookNode hook,
    FlameLayoutResult result,
    Map<String, dynamic> context,
    FlameGameWorld? gameWorld,
  ) {
    final container = _HookContainerComponent(
      hookId: hook.id,
      size: hook.size,
    );

    for (final child in hook.children) {
      final childComponent = render(child, context);
      final position = result.positions[child.id];
      if (position != null && childComponent is PositionComponent) {
        childComponent.position.setFrom(OffsetToVector2(position).toVector2());
      }
      container.add(childComponent);
    }

    for (final attachment in hook.attachedNodes.values) {
      final nodeComponent = renderAttachedNode(attachment, context);
      final position = result.positions[attachment.nodeId];
      if (position != null && nodeComponent is PositionComponent) {
        nodeComponent.position.setFrom(OffsetToVector2(position).toVector2());
      }
      container.add(nodeComponent);
    }

    return container;
  }
}

class _HookContainerComponent extends PositionComponent {
  _HookContainerComponent({
    required this.hookId,
    required Size size,
  }) : super(position: Vector2.zero(), size: SizeToVector2(size).toVector2());

  final String hookId;

  @override
  String toString() => 'HookContainer($hookId)';
}

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

/// Extension to convert Flutter [Offset] to Flame [Vector2].
extension OffsetToVector2 on Offset {
  /// Converts this [Offset] to a Flame [Vector2].
  Vector2 toVector2() => Vector2(dx, dy);
}

/// Extension to convert Flutter [Size] to Flame [Vector2].
extension SizeToVector2 on Size {
  /// Converts this [Size] to a Flame [Vector2].
  Vector2 toVector2() => Vector2(width, height);
}