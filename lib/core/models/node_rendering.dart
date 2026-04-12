/// 双重渲染系统的节点渲染能力。
///
/// 此模块定义了允许节点在Flutter（Widget树）和Flame（组件树）上下文中渲染的接口。
///
/// ## 架构
///
/// ```
/// Node
///   ├─ buildFlutterWidget() → Flutter Widget
///   └─ buildFlameComponent() → Flame Component
///
/// Position (存储在UILayoutService中，不在Node中)
///   └─ NodeAttachment中的LocalPosition
/// ```
///
/// ## 设计理念
///
/// - **节点是自治的**：它们不知道自己的位置
/// - **位置是外部的**：由UILayoutService通过NodeAttachment管理
/// - **双重渲染**：同一个节点可以在Flutter或Flame上下文中渲染
/// - **状态保持**：节点状态独立于渲染上下文
///
/// ## 使用方式
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

/// 为Node添加双重渲染能力的混入。
///
/// 此混入提供了节点在Flutter和Flame上下文中渲染自己的接口。
///
/// ## 实现指南
///
/// 当混入到Node时，实现两个渲染方法：
///
/// ```dart
/// class TextNode extends Node with NodeRendering {
///   TextNode({
///     required super.id,
///     required super.title,
///     super.content,
///   }) : super(
///           references: const {},
///           position: Offset.zero, // 将在第6阶段移除
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
/// ## Flutter Widget渲染
///
/// `buildFlutterWidget()`方法应返回一个Flutter Widget，
/// 在Flutter上下文中表示此节点（例如，在侧边栏、工具栏中）。
///
/// 指南：
/// - 使用`this`访问节点属性（标题、内容、元数据）
/// - 不要假设任何位置（位置由UILayoutService管理）
/// - 保持widget简单高效
/// - 尽可能使用const构造函数
///
/// ## Flame组件渲染
///
/// `buildFlameComponent()`方法应返回一个Flame组件，
/// 在Flame上下文中表示此节点（例如，在图中）。
///
/// 指南：
/// - 使用`this`访问节点属性
/// - 组件将由UILayoutService定位
/// - 实现交互处理（点击、拖动等）
/// - 缓存资源（Paint、TextPainter）以提高性能
mixin NodeRendering on Node {
  /// 构建此节点的Flutter Widget表示。
  ///
  /// 当节点需要在Flutter上下文中渲染时调用此方法
  /// （例如，侧边栏、工具栏、设置）。
  ///
  /// [context] 是Flutter BuildContext。
  ///
  /// 返回表示此节点的Widget。
  ///
  /// ## 示例
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

  /// 构建此节点的Flame组件表示。
  ///
  /// 当节点需要在Flame上下文中渲染时调用此方法
  /// （例如，在图可视化中）。
  ///
  /// [world] 是GraphWorld（Flame游戏世界）实例。
  ///
  /// 返回表示此节点的组件。
  ///
  /// ## 示例
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
  /// ## 性能提示
  ///
  /// - 缓存Paint对象（不要在渲染方法中创建）
  /// - 缓存TextPainter对象用于文本渲染
  /// - 使用带有大小的PositionComponent进行命中测试
  /// - 实现onTap、onDrag等交互方法
  Component buildFlameComponent(dynamic world);

  /// 获取在Flutter中渲染的首选大小。
  ///
  /// 这是对布局系统的提示。实际大小可能由
  /// Hook的布局策略调整。
  ///
  /// 返回首选大小，如果没有偏好则返回null。
  Size get preferredFlutterSize => size;

  /// 获取在Flame中渲染的首选大小。
  ///
  /// 这是对布局系统的提示。实际大小可能由
  /// Hook的布局策略调整。
  ///
  /// 返回首选大小，如果没有偏好则返回null。
  Size get preferredFlameSize => size;

  /// 检查此节点是否可以在Flutter上下文中渲染。
  ///
  /// 如果节点有Flutter widget表示则返回true。
  /// 如果节点仅支持Flame，则覆盖此方法返回false。
  bool get canRenderInFlutter => true;

  /// 检查此节点是否可以在Flame上下文中渲染。
  ///
  /// 如果节点有Flame组件表示则返回true。
  /// 如果节点仅支持Flutter，则覆盖此方法返回false。
  bool get canRenderInFlame => true;

  /// 验证此节点是否可以在给定上下文中渲染。
  ///
  /// 如果节点无法在请求的上下文中渲染，则抛出[StateError]。
  ///
  /// [isFlutter] 为true表示Flutter上下文，false表示Flame。
  void validateRendering(bool isFlutter) {
    if (isFlutter && !canRenderInFlutter) {
      throw StateError(
        '节点 $id 无法在Flutter上下文中渲染。'
        '实现buildFlutterWidget()或将canRenderInFlutter设置为true。',
      );
    }
    if (!isFlutter && !canRenderInFlame) {
      throw StateError(
        '节点 $id 无法在Flame上下文中渲染。'
        '实现buildFlameComponent()或将canRenderInFlame设置为true。',
      );
    }
  }
}

/// 基本节点的NodeRendering默认实现。
///
/// 这为没有自定义渲染逻辑的节点提供简单的占位widget/组件。
///
/// 插件可以将其混入到它们的节点类中以快速开始。
///
/// ## 示例
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
  Component buildFlameComponent(dynamic world) => _PlaceholderNodeComponent(node: this);
}

/// 没有自定义渲染的节点的占位Flame组件。
///
/// 提供基本的节点渲染功能:
/// - 显示节点标题
/// - 显示节点边框
/// - 支持基本的交互
class _PlaceholderNodeComponent extends PositionComponent {
  _PlaceholderNodeComponent({required this.node}) {
    // 设置组件大小
    size = Vector2(
      node.size.width.isFinite ? node.size.width : 200,
      node.size.height.isFinite ? node.size.height : 80,
    );

    // 设置组件位置
    position = Vector2(
      node.position.dx,
      node.position.dy,
    );
  }

  final Node node;

  @override
  void render(Canvas canvas) {
    // 绘制背景
    final backgroundColor = node.color != null
        ? Color(int.parse(node.color!))
        : const Color(0xFFFFFFFF);
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(size.toRect(), backgroundPaint);

    // 绘制边框
    final borderPaint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(size.toRect(), borderPaint);

    // 绘制标题
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.title,
        style: const TextStyle(
          color: Color(0xFF000000),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    );
    textPainter.layout(maxWidth: size.x - 16);
    textPainter.paint(canvas, const Offset(8, 8));
  }

  @override
  String toString() => 'PlaceholderNodeComponent(${node.id})';
}

/// 将Flutter Size转换为Flame Vector2的扩展。
extension SizeToVector2 on Size {
  /// 将此Size转换为Flame Vector2。
  Vector2 toVector2() => Vector2(width, height);
}
