/// FlutterRenderContext —— 位置无关渲染的 Flutter 目标（02 §3.1 / 架构 §7）。
///
/// Hook 渲染进 widget 树：Flutter 插件实现的 Hook 通过 mount 把自己
/// 画的 widget 挂进渲染树（`(context as FlutterRenderContext).mount(w)`）。
/// Hook 契约本身保持位置无关——core_data 不 import Flutter；
/// 可被渲染进任意 RenderContext（含全局 overlay——飞行壳层前提，03 §二）。
///
/// M7 修正（Hook 承载 UI，00"UI 是 Hook 构成的图"）：
/// - host：渲染宿主引用——Hook 渲染时经此解析服务（plugon DI），
///   构造自己的 UI（服务注入——插件 UI 不依赖组合根类型）
/// - sink：渲染结果收集（widget 列表；null = 丢弃，供测试）
///
/// M8 修正（组合根回调移除）：画布卡片拖入语义不再经渲染上下文穿线
/// （旧 onCardDrop 字段已删）——语义 = `CanvasCardDropSemantics` 壳层
/// 服务（宿主缺省 null + 插件 last-wins，drag_controller.dart），画布
/// 经 `host.serviceProvider` 运行时解析。渲染上下文回归纯渲染通道。
///
/// 节点打开 = 渲染节点 Hook（HookView）——**无 UI 行为分发回调**。
library;

import 'package:core_data/core_data.dart';
import 'package:flutter/widgets.dart';

import '../host/host_runtime.dart';

/// 拖拽起点回调（节点 id + 全局坐标——共享事务的 Phase 1 入口）。
typedef DragStartHandler = void Function(String nodeId, Offset position);

/// Flutter 渲染目标。
class FlutterRenderContext implements RenderContext {
  /// 注入宿主、渲染形态、数据层回调与渲染结果收集。
  FlutterRenderContext({
    this.host,
    this.kind,
    this.onDragStart,
    this.sink,
  });

  /// 渲染宿主（Hook 解析服务的通道；null = 测试环境）。
  final HostRuntime? host;

  /// 渲染形态（HookContext.kind：sidebar / graph / open …——
  /// Hook render 按形态分发自己的呈现，02 §1.2）。
  final String? kind;

  /// 拖拽起点记录（飞行视觉——拖拽源 Hook 的 Draggable 调用，
  /// 目标容器经 DragController 读取；M7）。
  final DragStartHandler? onDragStart;

  /// 渲染结果收集（widget 列表；null = 丢弃）。
  final List<Widget>? sink;

  /// 挂载：Hook 把自己画的 widget 放进渲染树。
  ///
  /// 由 Flutter 插件的 Hook 实现调用（Hook 代码可 import Flutter；
  /// core_data 契约本身零 Flutter 依赖）。
  void mount(Widget widget) {
    sink?.add(widget);
  }

  @override
  FlutterRenderContext createChildContext(Hook childHook) =>
      FlutterRenderContext(
        host: host,
        kind: kind,
        onDragStart: onDragStart,
        sink: sink,
      );
}
