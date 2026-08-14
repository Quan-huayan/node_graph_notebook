library;

import 'package:flutter/material.dart';

import 'package:plugin/plugin.dart';
import '../node_attachment.dart';
import '../ui_hook_tree.dart';
import 'renderer_base.dart';

/// A [RendererBase] implementation that produces Flutter [Widget] trees from
/// the UI hook tree, delegating to hook role wrappers via [HookRoleRegistry].
class FlutterRenderer extends RendererBase<Widget> {
  /// Creates a [FlutterRenderer] with the required [hookRoleRegistry] and
  /// optional [nodeWidgetBuilder].
  FlutterRenderer({
    required HookRoleRegistry hookRoleRegistry,
    this.nodeWidgetBuilder,
  }) : _hookRoleRegistry = hookRoleRegistry;

  final HookRoleRegistry _hookRoleRegistry;

  /// Optional builder for custom widgets per attached node.
  final Widget Function(String nodeId, NodeAttachment attachment, BuildContext context)?
      nodeWidgetBuilder;

  @override
  String get outputTypeName => 'Widget';

  @override
  Widget render(UIHookNode hook, Map<String, dynamic> context) {
    final buildContext = context['buildContext'] as BuildContext?;

    final wrappers = _hookRoleRegistry.getHookWrappers(hook.hookPointId);

    if (wrappers.isEmpty) {
      return _renderDefaultContainer(hook, buildContext);
    }

    final hookContext = _createContext(hook, buildContext);

    for (final wrapper in wrappers) {
      if (wrapper.hook.isVisible(hookContext)) {
        final widget = wrapper.hook.render(hookContext);

        return _applySizeConstraint(hook, widget);
      }
    }

    return _renderDefaultContainer(hook, buildContext);
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

    return _DefaultNodeWidget(
      nodeId: attachment.nodeId,
      attachment: attachment,
    );
  }

  HookContext _createContext(UIHookNode hook, BuildContext? buildContext) => BasicHookContext(
      data: {
        'buildContext': buildContext,
        'hook': hook,
        'children': hook.children,
        'attachedNodes': hook.attachedNodes,
      },
      hookAPIRegistry: _hookRoleRegistry.apiRegistry,
    );

  Widget _applySizeConstraint(UIHookNode hook, Widget widget) {
    if (hook.size.width.isFinite || hook.size.height.isFinite) {
      return SizedBox(
        width: hook.size.width.isFinite ? hook.size.width : null,
        height: hook.size.height.isFinite ? hook.size.height : null,
        child: widget,
      );
    }

    return widget;
  }

  Widget _renderDefaultContainer(UIHookNode hook, BuildContext? buildContext) {
    final children = <Widget>[];

    for (final child in hook.children) {
      children.add(render(child, {'buildContext': buildContext}));
    }

    for (final attachment in hook.attachedNodes.values) {
      children.add(renderAttachedNode(attachment, {'buildContext': buildContext}));
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

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