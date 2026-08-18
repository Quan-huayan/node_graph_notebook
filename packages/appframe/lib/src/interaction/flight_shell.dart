/// FlightShell —— 飞行壳层（03 §二）：独立于 Hook 树的过渡渲染层。
///
/// 问题：提交瞬间前端图结构变更导致 Hook 树重建——正在过渡的节点
/// 所属的树消失了。壳层 = 在全局 overlay 中渲染的独立过渡层。
///
/// 前提：Hook 渲染位置无关（02 §3.1）——壳层只是它的推论。
/// 壳层不接触数据层：不读 metadata、不发命令，纯渲染。
///
/// M7 落地（Flowing UI 视觉，00 宪章核心）：
/// - `present`：承接拖拽影像，可选择性地立即插入 OverlayEntry 执行
///   from → to 飞行（03 §二"提交"语义与视觉合流——旧实现 present 只改
///   状态机、fly 只画 overlay，调用方必须自行编排两步，成功/失败路径
///   各自手动 fly/bounce，状态与视觉脱节）
/// - `abort`：清理进行中的影像并回滚状态；`bounce` 用于失败回弹视觉
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

  /// 当前事务起点（供宿主读取/调试；无事务时为最后一次 present 值）。
  Offset get from => _from;

  /// 当前事务终点。
  Offset get to => _to;

  /// 是否有视觉影像挂在 overlay 上。
  bool get hasVisual => _entry != null;

  /// 承接拖拽影像，开始过渡（03 §一 Phase 3）。
  ///
  /// 提供 [overlay] + [child] 时本方法直接插入飞行影像并自动完成
  /// （动画结束 → 移除 → phase=committed）；不提供时保持既有纯状态机
  /// 行为（测试/非 widget 宿主经 [tick]/[commit] 驱动）。
  void present({
    required Offset from,
    required Offset to,
    OverlayState? overlay,
    Widget? child,
    Duration duration = const Duration(milliseconds: 280),
    void Function(bool committed)? onFinished,
  }) {
    _from = from;
    _to = to;
    _phase = FlightPhase.flying;
    if (overlay == null || child == null) {
      // 纯状态机路径：新事务开始，上一事务残留的影像必须清掉，
      // 否则旧 entry 的 onEnd 会回写 phase（快速连续 drop 竞态）。
      _removeVisual();
      return;
    }
    _startEntry(
      overlay: overlay,
      child: child,
      from: from,
      to: to,
      duration: duration,
      reverse: false,
      onFinished: onFinished ?? this.onFinished ?? _noop,
    );
  }

  /// **飞行视觉**（03 §二——Flowing UI 核心）：影像从 [from] 飞到 [to]。
  ///
  /// 保留的显式视觉入口；与 present 同一条 _startEntry 实现。动画完成
  /// 自动销毁、phase=committed 并回调 [onFinished]。
  void fly({
    required OverlayState overlay,
    required Widget child,
    required Offset from,
    required Offset to,
    Duration duration = const Duration(milliseconds: 280),
    required void Function(bool committed) onFinished,
  }) {
    _from = from;
    _to = to;
    _phase = FlightPhase.flying;
    _startEntry(
      overlay: overlay,
      child: child,
      from: from,
      to: to,
      duration: duration,
      reverse: false,
      onFinished: onFinished,
    );
  }

  /// **回弹视觉**（03 Phase 4 失败回弹）：影像从 [to] 弹回 [from]。
  ///
  /// 动画完成自动销毁、phase=aborted 并回调 [onFinished(false)]。
  void bounce({
    required OverlayState overlay,
    required Widget child,
    required Offset from,
    required Offset to,
    Duration duration = const Duration(milliseconds: 200),
    required void Function(bool committed) onFinished,
  }) {
    _from = from;
    _to = to;
    _phase = FlightPhase.flying;
    _startEntry(
      overlay: overlay,
      child: child,
      from: to,
      to: from,
      duration: duration,
      reverse: true,
      onFinished: onFinished,
    );
  }

  /// 每帧驱动（宿主渲染循环调用）。
  void tick(double progress) {
    if (_phase != FlightPhase.flying) {
      return;
    }
    onFrame?.call(progress, Offset.lerp(_from, _to, progress) ?? _to);
  }

  /// 提交：过渡完成 → 销毁影像（若有）→ 回调终态。
  void commit() {
    _phase = FlightPhase.committed;
    _removeVisual();
    onFinished?.call(true);
  }

  /// 回滚：过渡失败 → 销毁影像（若有）→ 回调终态，无持久化副作用。
  void abort() {
    _phase = FlightPhase.aborted;
    _removeVisual();
    onFinished?.call(false);
  }

  /// 统一视觉入口：先安全移除旧影像，再插入新 OverlayEntry。
  ///
  /// 中断保护：旧 entry 被替换后其 onEnd 不会再改状态/二次 remove
  /// （identity 校验），修复快速连续 fly/bounce 的竞态。
  void _startEntry({
    required OverlayState overlay,
    required Widget child,
    required Offset from,
    required Offset to,
    required Duration duration,
    required bool reverse,
    required void Function(bool committed) onFinished,
  }) {
    _removeVisual();
    late final OverlayEntry entry;
    void finish(bool committed) {
      if (!identical(_entry, entry)) {
        return; // 已被更新的影像替换（中断），旧回调不再生效。
      }
      _entry = null;
      if (entry.mounted) {
        entry.remove();
      }
      _phase = committed ? FlightPhase.committed : FlightPhase.aborted;
      onFinished(committed);
    }

    entry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: duration,
        curve: reverse ? Curves.easeInCubic : Curves.easeOutCubic,
        onEnd: () => finish(!reverse),
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

  /// 移除 overlay 影像（已为空则 no-op）。
  void _removeVisual() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
  }

  static void _noop(bool committed) {}
}
