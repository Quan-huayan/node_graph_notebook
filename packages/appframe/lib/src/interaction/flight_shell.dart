/// FlightShell —— 飞行壳层（03 §二）：独立于 Hook 树的过渡渲染层。
///
/// 问题：提交瞬间前端图结构变更导致 Hook 树重建——正在过渡的节点
/// 所属的树消失了。壳层 = 在全局 overlay 中渲染的独立过渡层。
///
/// 前提：Hook 渲染位置无关（02 §3.1）——壳层只是它的推论。
/// 壳层不接触数据层：不读 metadata、不发命令，纯渲染。
///
/// M7 落地（Flowing UI 视觉，00 宪章核心）：
/// - `fly`：影像从源位置**飞行**到目标位置（OverlayEntry +
///   TweenAnimationBuilder，无需 TickerProvider）→ 动画完成销毁
/// - `bounce`：失败**回弹**（目标 → 源，反向动画）
/// - 状态机保留（present/tick/commit/abort——03 §一 四阶段语义）
library;

import 'package:flutter/material.dart';

/// 飞行壳层阶段（03 §一 四阶段对应）。
enum FlightPhase {
  /// 空闲（无活跃事务）。
  idle,

  /// 过渡中（影像从源位置飞向目标）。
  flying,

  /// 已提交（动画完成，可销毁）。
  committed,

  /// 已回滚（失败回弹，可销毁）。
  aborted,
}

/// 飞行壳层：拖拽提交时的过渡渲染层。
class FlightShell {
  /// 注入帧回调与终态回调。
  FlightShell({this.onFrame, this.onFinished});

  /// 每帧插值回调（flying 期间）：progress 0..1 → 当前影像位置。
  final void Function(double progress, Offset position)? onFrame;

  /// 终态回调：committed=true 提交成功；false 回弹（失败）。
  final void Function(bool committed)? onFinished;

  FlightPhase _phase = FlightPhase.idle;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  OverlayEntry? _entry;

  /// 当前阶段。
  FlightPhase get phase => _phase;

  /// 承接拖拽影像，开始过渡（§5.3 第 6 步）。
  void present({required Offset from, required Offset to}) {
    _from = from;
    _to = to;
    _phase = FlightPhase.flying;
  }

  /// **飞行视觉**（M7 落地，03 §二——Flowing UI 核心）：影像从
  /// [from] 飞到 [to]（OverlayEntry + TweenAnimationBuilder，无
  /// TickerProvider 依赖），动画完成自动销毁并回调 [onFinished]。
  ///
  /// 壳层不接触数据层（03 §二：纯渲染）；与 present/abort 状态机
  /// 并存——present 是事务语义，fly 是视觉呈现。
  void fly({
    required OverlayState overlay,
    required Widget child,
    required Offset from,
    required Offset to,
    Duration duration = const Duration(milliseconds: 280),
    required void Function(bool committed) onFinished,
  }) {
    _entry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        onEnd: () {
          // M7.2 修复（运行时暴露）：动画完成自移除后 _entry 仍指向
          // 本条目——下一次 fly 的 _entry?.remove() 二次移除崩溃
          // （"An OverlayEntry should be removed only once"）。
          if (_entry == entry) {
            _entry = null;
          }
          if (entry.mounted) {
            entry.remove();
          }
          onFinished(true);
        },
        builder: (context, t, _) {
          final position = Offset.lerp(from, to, t) ?? to;
          return Positioned(
            left: position.dx,
            top: position.dy,
            child: IgnorePointer(child: child),
          );
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// **回弹视觉**（03 Phase 4 失败回弹）：影像从 [to] 弹回 [from]。
  void bounce({
    required OverlayState overlay,
    required Widget child,
    required Offset from,
    required Offset to,
    Duration duration = const Duration(milliseconds: 200),
    required void Function(bool committed) onFinished,
  }) {
    _entry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeInCubic,
        onEnd: () {
          // M7.2 修复（与 fly 同）：自移除后清空 _entry，防二次移除。
          if (_entry == entry) {
            _entry = null;
          }
          if (entry.mounted) {
            entry.remove();
          }
          onFinished(false);
        },
        builder: (context, t, _) {
          final position = Offset.lerp(to, from, t) ?? from;
          return Positioned(
            left: position.dx,
            top: position.dy,
            child: IgnorePointer(child: child),
          );
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// 每帧驱动（宿主渲染循环调用）。
  void tick(double progress) {
    if (_phase != FlightPhase.flying) {
      return;
    }
    onFrame?.call(progress, Offset.lerp(_from, _to, progress) ?? _to);
  }

  /// 提交：渐变到目标位置完成 → 销毁（03 §二）。
  void commit() {
    _phase = FlightPhase.committed;
    onFinished?.call(true);
  }

  /// 回滚：影像弹回源位置 → 销毁，无持久化副作用（03 Phase 4）。
  void abort() {
    _phase = FlightPhase.aborted;
    onFinished?.call(false);
  }
}
