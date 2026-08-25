/// GraphCanvas —— 画布（M6 graph 插件，00 杀手演示"拖上画布→图节点"）。
///
/// - **成员 = 外观位置**（判据②）：有 `position.graph.<nodeId>` 键的节点
///   才显示；拖入画布 = 位置直写，零结构写入（投影不变式 4.1）。
/// - **相机**：InteractiveViewer（pan/zoom），`camera.main.<hookId>`
///   持久化 + 启动恢复（02 §2.3 键方案 / architecture §5.5）。
/// - **视口可见性**：QuadTreeViewportQuery 过滤世界视口矩形（10⁶ 空间索引，
///   M6 数据量小：全量可见；路径真实）。
/// - 孤儿位置键惰性 GC（02 §2.3：getByPrefix 触达时对照 Graph 清理）。
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'canvas_concept.dart';
import 'connection_concept.dart';
import 'layout/layout_dialog.dart';
import 'node_card.dart';
import 'node_dialogs.dart';

/// 画布。
///
/// M7 修正（Hook 承载 UI / app 零 UI）：画布由 CanvasHook.render 挂载；
/// 节点打开 = **渲染节点 Hook**（HookView——AIHook 对话视图、笔记 Hook
/// 编辑器视图——无 app 行为分发）；卡片 drop 语义 = 数据层回调
/// （组合根注入，01 拍板 #32）。
///
/// M7.1（画布成员 Hook 化）：成员卡片 = 成员节点自己的物化 Hook 渲染
/// （kind='graph'，_PositionedCard——UIManager 物化实例 + 失效定向重建）；
/// 画布保留 commandBus 订阅（连接线 = 画布级派生状态，ConnectionConcept
/// 无 Hook 物化——10⁶ 优化项：连接 Hook 化）。
class GraphCanvas extends StatefulWidget {
  /// 注入宿主组合根。
  ///
  /// M8（组合根回调移除）：卡片 drop 语义不再经本组件回调注入——
  /// 语义 = `CanvasCardDropSemantics` 壳层服务（`host.serviceProvider`
  /// 运行时解析，宿主缺省 null = 默认连接），与侧边栏/工具栏同族。
  const GraphCanvas({super.key, required this.host});

  /// 宿主组合根。
  final HostRuntime host;

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<GraphCanvas> {
  final TransformationController _camera = TransformationController();
  final GlobalKey _viewportKey = GlobalKey();
  Timer? _cameraSaveTimer;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  late final String _cameraKey;

  /// P2-4（10⁶ 窗口化渲染接线）：视口推送防抖（与相机持久化同频）、
  /// 上次已推矩形（无变化不重推）与最近一次量得的视口尺寸。
  Timer? _viewportPushTimer;
  ValueRect? _pushedViewport;
  Size _lastViewportSize = Size.zero;

  /// 缩放钳制（手势与程序化缩放共用；M7.3 画布缩放）。
  static const double _minScale = 0.2;
  static const double _maxScale = 4;

  /// 缩放步进（滚轮与按钮共用相对因子）。
  static const double _zoomStep = 1.25;

  /// 适应视图的缩放钳制（避免极小图过度放大/极大图缩死）。
  static const double _fitMinScale = 0.1;
  static const double _fitMaxScale = 2;

  /// 拖拽中的临时位置（nodeId → 场景坐标）——卡片与连线实时跟随，
  /// 松手 drop 时落盘（判据②），期间不写存储。
  final Map<String, Offset> _dragPreview = <String, Offset>{};

  /// 拖拽锚点（nodeId → (抓取起点场景坐标, 原位中心)）——卡片位移 =
  /// 指针位移（跟手），预览与落盘同一语义，松手无跳变。
  final Map<String, (Offset, Offset)> _dragAnchors =
      <String, (Offset, Offset)>{};

  /// 画布指针按下：空白右键 = 画布菜单（布局…/适应视图，M7.3）；
  /// 否则双击检测（300ms 窗口 + 20px 距离阈值；不参与手势 arena）。
  ///
  /// 事件冒泡：卡片上的右键先由 NodeCard 的 Listener 消费（卡片菜单），
  /// 本处只响应空白处（卡片区域判定——防双菜单叠加）。
  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == kSecondaryMouseButton) {
      if (!_isOverCard(event.position)) {
        _showCanvasMenu(event.position);
      }
      return;
    }
    final now = DateTime.now();
    final last = _lastTapTime;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 300) &&
        (_lastTapPosition! - event.position).distance < 20) {
      _lastTapTime = null;
      _lastTapPosition = null;
      _createNodeAt(event.localPosition);
    } else {
      _lastTapTime = now;
      _lastTapPosition = event.position;
    }
  }

  /// 右键位置是否落在某成员卡片区域（卡片右键由卡片菜单消费，
  /// 画布菜单只响应空白处，M7.3）。
  bool _isOverCard(Offset globalPoint) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return false;
    }
    final scene = _camera.toScene(box.globalToLocal(globalPoint));
    for (final entry in _readMembers().entries) {
      final half = (_memberSize(entry.key) ?? defaultCardSize) / 2;
      final rect = Rect.fromCenter(
        center: entry.value,
        width: half.width * 2,
        height: half.height * 2,
      );
      if (rect.contains(scene)) {
        return true;
      }
    }
    return false;
  }

  /// 画布空白右键菜单（M7.3）：布局对话框 / 适应视图。
  Future<void> _showCanvasMenu(Offset position) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'layout',
          child: Text('${widget.host.i18nService.t('layout.title')}…'),
        ),
        PopupMenuItem<String>(
          value: 'fit',
          child: Text(widget.host.i18nService.t('canvas.zoomFit')),
        ),
      ],
    );
    if (!mounted) {
      return;
    }
    switch (action) {
      case 'layout':
        await showDialog<void>(
          context: context,
          builder: (context) => CanvasLayoutDialog(host: widget.host),
        );
      case 'fit':
        _fitToView();
    }
  }

  /// 滚轮缩放（以指针位置为锚点，M7.3）：向上滚放大、向下滚缩小。
  /// 程序化写矩阵不受 InteractiveViewer 手势钳制，自行 clamp。
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final anchor = _camera.toScene(box.globalToLocal(event.position));
    final factor = event.scrollDelta.dy < 0 ? _zoomStep : 1 / _zoomStep;
    _zoomAroundScene(anchor, factor);
  }

  /// 场景坐标锚点缩放（相对因子）：矩阵 = M · T(anchor) · S(rel) · T(-anchor)。
  void _zoomAroundScene(Offset anchor, double factor) {
    final current = _camera.value.getMaxScaleOnAxis();
    final relative = (current * factor).clamp(_minScale, _maxScale) / current;
    if ((relative - 1).abs() < 0.001) {
      return;
    }
    final m = _camera.value.clone()
      ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
      ..scaleByDouble(relative, relative, 1, 1)
      ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);
    _camera.value = m;
  }

  /// 以视口中心为锚缩放（缩放按钮）。
  void _zoomBy(double factor) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    _zoomAroundScene(
      _camera.toScene(Offset(box.size.width / 2, box.size.height / 2)),
      factor,
    );
  }

  /// 适应视图：成员包围盒（含卡片半尺寸）居中缩放到视口。
  void _fitToView() {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final positions = _readMembers();
    if (positions.isEmpty) {
      _camera.value = Matrix4.identity();
      return;
    }
    var first = true;
    var minX = 0.0;
    var maxX = 0.0;
    var minY = 0.0;
    var maxY = 0.0;
    for (final entry in positions.entries) {
      // 包围盒含卡片半尺寸（中心定位语义；样式尺寸覆盖默认）。
      final size = _memberSize(entry.key) ?? defaultCardSize;
      final p = entry.value;
      final half = size / 2;
      if (first) {
        minX = p.dx - half.width;
        maxX = p.dx + half.width;
        minY = p.dy - half.height;
        maxY = p.dy + half.height;
        first = false;
      } else {
        minX = math.min(minX, p.dx - half.width);
        maxX = math.max(maxX, p.dx + half.width);
        minY = math.min(minY, p.dy - half.height);
        maxY = math.max(maxY, p.dy + half.height);
      }
    }
    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    final scale = math
        .min(box.size.width / bounds.width, box.size.height / bounds.height)
        .clamp(_fitMinScale, _fitMaxScale);
    final center = bounds.center;
    final m = Matrix4.identity()
      ..translateByDouble(
        box.size.width / 2 - center.dx * scale,
        box.size.height / 2 - center.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
    _camera.value = m;
  }

  @override
  void initState() {
    super.initState();
    // 相机键身份：画布 Hook 的 hookId（02 §2.3：camera.main.<hookId>）。
    _cameraKey = 'camera.main.${_canvasHookId()}';
    _restoreCamera();
    _camera.addListener(_onCameraChanged);
    // M7.1（UIManager 事件驱动）：画布级刷新 = **结构事件**（成员增删/
    // 连接建删——ChangeKind 均为 structure）；成员 data 变更由成员卡片
    // 自身订阅定向重建（本画布不重建，架构 §5.2 增量粒度）。
    // 外观直写（位置/相机）由本 widget 自管 setState（ui 不发事件）。
    if (widget.host.started) {
      widget.host.uiManager.addListener(_onInvalidation);
      // P2-4：首帧后推一次视口（初始窗口化物化——相机未变化前
      // listener 不会触发）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pushViewport();
        }
      });
    }
    // M7.2（D2 外部写入方）：可见性对话框等经 UIStateStore 直写位置键
    // → 观察者通道 → 画布按关心前缀定向刷新（02 §2.3 失效语义）。
    widget.host.uiStateStore.attach(_onUiStateChanged);
  }

  @override
  void dispose() {
    widget.host.uiStateStore.detach(_onUiStateChanged);
    if (widget.host.started) {
      widget.host.uiManager.removeListener(_onInvalidation);
    }
    _cameraSaveTimer?.cancel();
    _viewportPushTimer?.cancel();
    _camera.removeListener(_onCameraChanged);
    _camera.dispose();
    super.dispose();
  }

  /// 相机变化（平移/缩放）：防抖持久化 + 防抖推视口 + **立即重建
  /// 可见集**——InteractiveViewer 的变换是内部 Transform，不触发本
  /// widget 重建；不做这步，平移后可见集滞后（卡片不出现）。
  void _onCameraChanged() {
    _scheduleCameraSave();
    _scheduleViewportPush();
    if (mounted) {
      setState(() {});
    }
  }

  /// 外观键变更 → 画布定向刷新（只关心 position/style 前缀——相机/其他
  /// 域不影响成员渲染；写入方=自身时 setState 批处理无重复成本）。
  ///
  /// **phase 感知**：孤儿 GC 在 build 内 remove 键会同步触发本监听——
  /// 立即 setState 会"build 中 setState"崩溃（schedulerPhase ==
  /// persistentCallbacks）；此时当前帧重建已覆盖变更（移除即生效），
  /// post-frame 补一次仅生产环境跑（测试环境 postFrame 不随 pump 跑，
  /// 无害）。外部写入/事件处理器（phase == idle）→ 立即 setState，
  /// 下一帧重建（测试可断言）。
  void _onUiStateChanged(String key) {
    final relevant =
        key.startsWith(canvasPositionPrefix) ||
        key.startsWith(canvasStylePrefix);
    if (!relevant || !mounted) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// 结构事件 → 画布级重建（成员增删/连接建删）；data 事件忽略
  /// （成员卡片自身订阅——连接实例无 Hook 物化，连接变更均为结构）。
  void _onInvalidation(InvalidationEvent event) {
    if (event.changeKind == ChangeKind.structure && mounted) {
      setState(() {});
    }
  }

  /// 画布 HookId：首个命中 CanvasConcept 的节点（缺省 'canvas@graph'）。
  String _canvasHookId() {
    for (final node in widget.host.graph.getAll()) {
      if (const CanvasConcept().validate(node)) {
        return const CanvasConcept()
            .createHook(node, const HookContext(kind: 'graph'))
            .hookId;
      }
    }
    return 'canvas@graph';
  }

  /// 相机恢复（architecture §5.5）：`camera.main.<hookId>` → 完整矩阵
  /// （平移 + 缩放，M7.3）。旧数据只有平移（缩放归 1）——恒等缩放兼容。
  void _restoreCamera() {
    final saved = widget.host.uiStateStore.get(_cameraKey);
    if (saved is! Map<String, dynamic>) {
      return;
    }
    final m = saved['m'];
    if (m is List && m.length == 16 && m.every((e) => e is num)) {
      _camera.value = Matrix4.fromList(
        m.map((e) => (e as num).toDouble()).toList(),
      );
    }
  }

  /// 相机变化防抖持久化（300ms；量小，KV 直写）。
  void _scheduleCameraSave() {
    _cameraSaveTimer?.cancel();
    _cameraSaveTimer = Timer(const Duration(milliseconds: 300), () {
      widget.host.uiStateStore.set(_cameraKey, <String, dynamic>{
        'm': _camera.value.storage.toList(),
      });
    });
  }

  /// P2-4：视口变化防抖推给 UIManager（窗口化物化，架构 §5.1——
  /// `onViewportChanged` 的生产接线）。
  void _scheduleViewportPush() {
    _viewportPushTimer?.cancel();
    _viewportPushTimer = Timer(
      const Duration(milliseconds: 300),
      _pushViewport,
    );
  }

  /// 计算当前可见场景矩形并推给 UIManager（矩形未变则跳过）。
  ///
  /// 矩形 = 相机矩阵对**真实视口尺寸**（LayoutBuilder 约束）的逆变换——
  /// 不是 MediaQuery 全屏尺寸（M6 失败模式的修正，见 build 修正记录）。
  void _pushViewport() {
    if (!mounted || !widget.host.started || _lastViewportSize == Size.zero) {
      return; // 未量过视口尺寸（首帧前）→ 等 LayoutBuilder 触发。
    }
    final rect = _visibleSceneRectFor(_lastViewportSize);
    final last = _pushedViewport;
    if (last != null &&
        (last.x - rect.x).abs() < 0.5 &&
        (last.y - rect.y).abs() < 0.5 &&
        (last.width - rect.width).abs() < 0.5 &&
        (last.height - rect.height).abs() < 0.5) {
      return;
    }
    _pushedViewport = rect;
    widget.host.uiManager.onViewportChanged(rect, kind: 'graph');
  }

  /// 可见场景矩形（相机逆变换 × 视口尺寸 + 边缘余量——渲染与推送
  /// 共用同一几何，命中测试与渲染列表同源）。
  ValueRect _visibleSceneRectFor(Size viewportSize) {
    final rect = _visibleSceneRect(viewportSize);
    return ValueRect(
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
    );
  }

  /// 可见场景矩形（含 [kVisibleMargin] 边缘余量：卡片在视口边缘
  /// 附近不被滤出，平移时无闪现）。
  Rect _visibleSceneRect(Size viewportSize) {
    final tl = _camera.toScene(Offset.zero);
    final br = _camera.toScene(Offset(viewportSize.width, viewportSize.height));
    return Rect.fromLTRB(
      math.min(tl.dx, br.dx) - kVisibleMargin,
      math.min(tl.dy, br.dy) - kVisibleMargin,
      math.max(tl.dx, br.dx) + kVisibleMargin,
      math.max(tl.dy, br.dy) + kVisibleMargin,
    );
  }

  /// 可见集边缘余量（px；渲染列表扩展，避免平移/缩放时卡片闪现）。
  static const double kVisibleMargin = 200;

  /// 成员样式尺寸（样式键 → size；无样式 → 默认，M7.3）。
  Size? _memberSize(String nodeId) {
    final style = parseNodeStyle(
      widget.host.uiStateStore.get(canvasStyleKey(nodeId)),
    );
    return style?.size;
  }

  /// 画布成员读取 + 孤儿键惰性 GC（02 §2.3：触达时对照 Graph 清理）。
  Map<String, Offset> _readMembers() {
    final positions = <String, Offset>{};
    final orphans = <String>[];
    widget.host.uiStateStore.getByPrefix(canvasPositionPrefix).forEach((
      key,
      value,
    ) {
      final nodeId = key.substring(canvasPositionPrefix.length);
      final position = parseCanvasPosition(value);
      if (position == null || widget.host.graph.get(nodeId) == null) {
        orphans.add(key); // 损坏值 / 节点已不存在 → 外观孤儿，惰性清理。
        return;
      }
      positions[nodeId] = position;
    });
    if (orphans.isNotEmpty) {
      orphans.forEach(widget.host.uiStateStore.remove);
    }
    return positions;
  }

  /// 落点统一判定（卡片 DragTarget 与画布 DragTarget 共用）：
  /// 落点距某成员卡片中心 < 容差 → 语义分发（M8：`CanvasCardDropSemantics`
  /// 壳层服务——宿主缺省 null = 默认连接；插件 last-wins 覆盖，如 AI
  /// 节点接收拖入 = `DropIntoAICommand` 数据命令。命令非 null = 已消费，
  /// 不执行默认连接）；否则 → 位置直写（判据② 外观，零结构写入）。
  ///
  /// 修正记录：初版连接必须精确落在卡片上（DragTarget 命中），
  /// 用户"拖过之后就判别不上"——就近判定 + 容差解决。
  Future<void> _resolveDrop(String nodeId, Offset globalPoint) async {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final scene = _camera.toScene(box.globalToLocal(globalPoint));
    final positions = _readMembers();
    String? nearest;
    var nearestDistance = double.infinity;
    for (final entry in positions.entries) {
      if (entry.key == nodeId) {
        continue; // 自连接不判定。
      }
      final distance = (entry.value - scene).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = entry.key;
      }
    }
    // 连接容差：卡片中心到边缘 + 32px（拖到卡片附近即连；按目标样式尺寸）。
    var connectTolerance = 0.0;
    if (nearest != null) {
      final targetSize = _memberSize(nearest) ?? defaultCardSize;
      connectTolerance = targetSize.width / 2 + 32;
    }
    if (nearest != null && nearestDistance < connectTolerance) {
      // M8：语义判定归系统（CanvasCardDropSemantics 壳层服务——
      // 拖拽语义服务家族，drag_controller.dart；插件 last-wins）。
      // 命令非 null = 已消费（含撞环拒绝），不执行默认连接。
      final command = widget.host.serviceProvider
          .get<CanvasCardDropSemantics>()(draggedId: nodeId, targetId: nearest);
      if (command != null) {
        try {
          await widget.host.commandBus.dispatch<Command, WriteResult>(command);
        } on CycleError {
          return; // 已处理（拒绝），不落入默认连接语义。
        } on IOException {
          _showError(widget.host.i18nService.t('error.saveFailed'));
          return;
        } on Exception catch (error) {
          _showError(
            '${widget.host.i18nService.t('error.operationFailed')}: $error',
          );
          return;
        }
        return;
      }
      _connect(nodeId, nearest);
      return;
    }
    // 移动（判据②）：位置直写，无任何结构写入。
    // drop offset 是"卡片左上 + 位移"（childDragAnchorStrategy），
    // position 语义是卡片中心——补半尺寸偏移（样式尺寸），与拖拽预览
    // 一致，无跳变。
    final draggedSize = _memberSize(nodeId) ?? defaultCardSize;
    final position =
        scene + Offset(draggedSize.width / 2, draggedSize.height / 2);
    final wasOnCanvas =
        widget.host.uiStateStore.get(canvasPositionKey(nodeId)) != null;
    widget.host.uiStateStore.set(canvasPositionKey(nodeId), <String, dynamic>{
      'x': position.dx,
      'y': position.dy,
    });
    if (mounted) {
      setState(() {});
      // 仅首次拖入画布提示（画布内移动是拖拽即时反馈，提示反而诡异）。
      if (!wasOnCanvas) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.host.i18nService.t('canvas.moved')}「${widget.host.graph.get(nodeId)?.title ?? nodeId}」',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// 拖拽开始：记录抓取锚点（起点场景坐标 + 原位中心）。
  void _onDragStart(String nodeId, Offset globalPoint) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final start = _camera.toScene(box.globalToLocal(globalPoint));
    final base = _dragPreview[nodeId] ?? _readMembers()[nodeId];
    if (base == null) {
      return;
    }
    _dragAnchors[nodeId] = (start, base);
  }

  /// 拖拽中实时预览（卡片 + 连线跟随；不写存储，松手才落盘）。
  /// 卡片位移 = 指针位移（跟手，抓取点相对位置不变）。
  void _onDragPreview(String nodeId, Offset globalPoint) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final scene = _camera.toScene(box.globalToLocal(globalPoint));
    final anchor = _dragAnchors[nodeId];
    _dragPreview[nodeId] = anchor == null
        ? scene // 兜底：无锚点（异常路径）直接跟随指针。
        : anchor.$2 + (scene - anchor.$1);
    if (mounted) {
      setState(() {});
    }
  }

  /// 拖拽结束：清理预览与锚点（drop 已由 _resolveDrop 落盘）。
  void _onDragEnd(String nodeId) {
    _dragAnchors.remove(nodeId);
    if (_dragPreview.remove(nodeId) != null && mounted) {
      setState(() {});
    }
  }

  /// 建立连接（无向；已连接幂等——ConnectNodesHandler 判定）。
  Future<void> _connect(String fromId, String toId) async {
    try {
      await widget.host.commandBus
          .dispatch<ConnectNodesCommand, ConnectNodesResult>(
            ConnectNodesCommand(from: fromId, to: toId),
          );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.host.i18nService.t('canvas.connected')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } on CycleError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.host.i18nService.t('canvas.cycle'))),
        );
      }
    } on IOException {
      _showError(widget.host.i18nService.t('error.saveFailed'));
    } catch (error) {
      _showError(
        '${widget.host.i18nService.t('error.operationFailed')}: $error',
      );
    }
  }

  /// 失败反馈（架构 §8：禁止静默失败）。
  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) =>
      // 世界范围 = 视口尺寸（LayoutBuilder 约束）∪ 成员范围——画布至少
      // 铺满视口（用户感知"画布"），成员超出时扩展（含负坐标偏移）。
      // 修正记录：初版最小 800x600，大窗口下画布只占左上角一小块。
      LayoutBuilder(
        builder: (context, constraints) {
          // P2-4：视口尺寸变化（窗口 resize 等）→ 防抖推视口
          // （相机 listener 只覆盖平移/缩放）。
          if (constraints.maxWidth != _lastViewportSize.width ||
              constraints.maxHeight != _lastViewportSize.height) {
            _lastViewportSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            _scheduleViewportPush();
          }
          // 成员位置 = 落盘位置 + 拖拽中临时预览（卡片/连线实时跟随）。
          final positions = _readMembers()..addAll(_dragPreview);
          var minX = 0.0;
          var minY = 0.0;
          var maxX = constraints.maxWidth;
          var maxY = constraints.maxHeight;
          for (final entry in positions.entries) {
            // 覆盖卡片 Positioned 区域（中心 ± 半尺寸；样式尺寸）——
            // 仅负区产生偏移。
            final half = (_memberSize(entry.key) ?? defaultCardSize) / 2;
            final position = entry.value;
            minX = minX > position.dx - half.width
                ? position.dx - half.width
                : minX;
            minY = minY > position.dy - half.height
                ? position.dy - half.height
                : minY;
            maxX = maxX < position.dx + half.width
                ? position.dx + half.width
                : maxX;
            maxY = maxY < position.dy + half.height
                ? position.dy + half.height
                : maxY;
          }
          // 世界原点偏移（负坐标 → 容器内非负）。
          final worldOffset = Offset(
            minX < 0 ? -minX : 0,
            minY < 0 ? -minY : 0,
          );
          // P2-4（10⁶ 窗口化渲染落地，架构 §7"每帧渲染 ≤ 视口内 Hook 数"
          // 的画布侧真实机制）：成员卡片渲染 = **可见集**（照位置键排序
          // 保证确定性）。
          //
          // 修正记录：初版按 QuadTreeViewportQuery 视口过滤渲染——视口矩形用
          // MediaQuery 全屏尺寸推算，与画布实际视口（偏移侧边栏/AppBar）不一致，
          // 相机缩放后卡片被滤出渲染列表 → 不渲染即不命中 → 所有事件按空白判
          // （右键失效/连接判定失败）。本版修正另一半：矩形 = 相机矩阵对
          // LayoutBuilder 真实视口尺寸的逆变换（+ kVisibleMargin 边缘余量），
          // 渲染列表与命中测试同源——可见即命中。世界范围仍由**全量**位置
          // 决定（平移/缩放无跳变）；孤儿 GC 仍为触达时全量扫描。
          final visibleRect = _visibleSceneRect(
            Size(constraints.maxWidth, constraints.maxHeight),
          );
          final memberIds =
              positions.keys
                  .where((id) => visibleRect.contains(positions[id]!))
                  .toList()
                ..sort();

          // 连接线：连接实例（L1）→ 两端位置（端点无位置/未物化 → 跳过）。
          // 坐标相对世界原点偏移（与卡片一致，容器内命中/渲染一致）。
          // P2-4：至少一端可见才渲染（两端均不可见 → 线整体不可见）。
          final lines = <(Offset, Offset)>[];
          for (final conn in widget.host.graph.getAll()) {
            if (!const ConnectionConcept().validate(conn)) {
              continue;
            }
            final from = positions[conn.references['from']];
            final to = positions[conn.references['to']];
            if (from == null || to == null) {
              continue;
            }
            if (!visibleRect.contains(from) && !visibleRect.contains(to)) {
              continue;
            }
            lines.add((from + worldOffset, to + worldOffset));
          }

          return DragTarget<String>(
            onAcceptWithDetails: (details) =>
                _resolveDrop(details.data, details.offset),
            builder: (context, candidates, rejected) =>
                // 画布级背景固定（不随 candidates 高亮——拖拽中全画布
                // 背景切换会闪；目标卡片高亮保留在 NodeCard）。
                Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        key: _viewportKey,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Listener(
                          // 画布空白双击 = 创建节点（判据① 数据命令 + 位置键直写）。
                          // 自实现双击检测（Listener 不参与手势 arena——GestureDetector 的
                          // DoubleTap 识别器会抢占 arena 使 pan 失效，实测坑）。
                          onPointerDown: _handlePointerDown,
                          // 滚轮缩放（M7.3）：以指针为锚，向上放大/向下缩小。
                          onPointerSignal: _handlePointerSignal,
                          child: ClipRect(
                            child: InteractiveViewer(
                              transformationController: _camera,
                              constrained: false,
                              // M7.3 画布缩放：滚轮/捏合 + 按钮，矩阵持久化恢复。
                              scaleEnabled: true,
                              minScale: _minScale,
                              maxScale: _maxScale,
                              // constrained: false + 缺省边界零余量 → 场景视口越界即钳零
                              // （逆向映射边界检查），任何右/下平移被吞掉。余量使平移自由。
                              boundaryMargin: const EdgeInsets.all(2000),
                              child: SizedBox(
                                width: maxX - minX + 160,
                                height: maxY - minY + 160,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // 网格背景（画布视觉感知）。
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _GridPainter(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                    // 连接线在卡片下层（卡片遮挡线端）。
                                    if (lines.isNotEmpty)
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _ConnectionPainter(
                                            lines: lines,
                                          ),
                                        ),
                                      ),
                                    // 空状态提示（画布功能引导；P2-4 起以
                                    // 全量位置判空——可见集为空可能只是
                                    // 平移到空白处，不显示"空画布"提示）。
                                    if (positions.isEmpty)
                                      Positioned(
                                        left: constraints.maxWidth / 2 - 160,
                                        top: constraints.maxHeight / 2 - 30,
                                        width: 320,
                                        child: IgnorePointer(
                                          child: Text(
                                            widget.host.i18nService.t(
                                              'canvas.empty',
                                            ),
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outline,
                                                ),
                                          ),
                                        ),
                                      ),
                                    for (final nodeId in memberIds)
                                      _PositionedCard(
                                        key: ValueKey('card-$nodeId'),
                                        node: widget.host.graph.get(nodeId)!,
                                        host: widget.host,
                                        position:
                                            positions[nodeId]! + worldOffset,
                                        onTap: () => _openNode(context, nodeId),
                                        onConnectRequest: _resolveDrop,
                                        onDragStart: _onDragStart,
                                        onDragUpdate: _onDragPreview,
                                        onDragEnd: _onDragEnd,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 缩放按钮组（视口右下角悬浮，不随相机变换，M7.3）。
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _ZoomControls(
                        i18n: widget.host.i18nService,
                        onZoomIn: () => _zoomBy(_zoomStep),
                        onZoomOut: () => _zoomBy(1 / _zoomStep),
                        onFit: _fitToView,
                      ),
                    ),
                  ],
                ),
          );
        },
      );

  /// 双击空白创建节点：对话框 → CreateNodeCommand → 位置键直写。
  Future<void> _createNodeAt(Offset viewportPoint) async {
    final form = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => NodeEditDialog(
        dialogTitle: widget.host.i18nService.t('node.create'),
        i18n: widget.host.i18nService,
      ),
    );
    if (form == null || !mounted) {
      return;
    }
    final id = newNodeId();
    // M7 回补：创建对话框带类型选择（笔记/文件夹/AI 节点）——
    // kind 是 metadata（数据），归属判定走结构匹配（00 删除清单无
    // instanceOf；文件夹/AI 节点由本流程产生）。
    final kind = form['kind'] as String?;
    try {
      await widget.host.commandBus
          .dispatch<CreateNodeCommand, CreateNodeResult>(
            CreateNodeCommand(
              id: id,
              title: form['title'] as String,
              content: form['content'] as String,
              metadata: kind == null || kind == 'note'
                  ? null
                  : <String, dynamic>{'kind': kind},
            ),
          );
    } on IOException {
      _showError(widget.host.i18nService.t('error.saveFailed'));
      return;
    } catch (error) {
      _showError(
        '${widget.host.i18nService.t('error.operationFailed')}: $error',
      );
      return;
    }
    // 画布成员 = 外观位置（判据②）：新节点落点在双击处。
    final scene = _camera.toScene(viewportPoint);
    widget.host.uiStateStore.set(canvasPositionKey(id), <String, dynamic>{
      'x': scene.dx,
      'y': scene.dy,
    });
    if (mounted) {
      setState(() {});
    }
  }

  /// 打开节点 = **渲染节点 Hook**（M7 修正，00"UI 是 Hook 构成的图"）：
  /// AIHook → 对话视图；笔记 Hook（NoteConcept）→ 编辑器视图——
  /// 无 app 行为分发，插件 Hook 渲染自己的 UI。
  ///
  /// M7.2（D1 弹框归属，用户裁决）：画布打开 = **CanvasConcept 责任**——
  /// 外壳（关闭按钮 + 回收）由画布提供，内容 = 节点自己的 Hook。
  /// recycleOnDispose：关闭即回收物化 Hook（窗口化，M7.1）。
  void _openNode(BuildContext context, String nodeId) {
    if (widget.host.graph.get(nodeId) == null) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 640,
          height: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 外壳：关闭按钮（画布发起、画布负责，M7.2 D1）。
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: widget.host.i18nService.t('dialog.close'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: HookView(
                  host: widget.host,
                  nodeId: nodeId,
                  kind: 'open',
                  recycleOnDispose: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 世界坐标定位的节点卡片（Positioned + 居中于位置点）。
///
/// M7.1（画布成员 Hook 化）：**卡片体 = 成员节点自己的物化 Hook 渲染**
/// （kind='graph'，位置无关）——画布只提供定位与交互壳（拖拽/连接/
/// 菜单），不代替节点呈现。物化 Hook 未挂载（兜底 / 未提供 'graph'
/// 形态）→ 回退 GenericNodeCardBody（永不空洞）。失效事件订阅：
/// 只命中本成员节点的 data/structure 变更才重建本卡片（定向）。
class _PositionedCard extends StatefulWidget {
  const _PositionedCard({
    super.key,
    required this.node,
    required this.host,
    required this.position,
    required this.onTap,
    this.onConnectRequest,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final Node node;
  final HostRuntime host;
  final Offset position;
  final VoidCallback onTap;

  final void Function(String draggedId, Offset globalPoint)? onConnectRequest;
  final void Function(String nodeId, Offset globalPoint)? onDragStart;
  final void Function(String nodeId, Offset globalPoint)? onDragUpdate;
  final void Function(String nodeId)? onDragEnd;

  @override
  State<_PositionedCard> createState() => _PositionedCardState();
}

class _PositionedCardState extends State<_PositionedCard> {
  @override
  void initState() {
    super.initState();
    if (widget.host.started) {
      widget.host.uiManager.addListener(_onInvalidation);
    }
  }

  @override
  void dispose() {
    if (widget.host.started) {
      widget.host.uiManager.removeListener(_onInvalidation);
    }
    super.dispose();
  }

  /// 失效事件 → 定向重建（data/structure 命中本成员才重建本卡片）。
  void _onInvalidation(InvalidationEvent event) {
    if (event.nodeIds.contains(widget.node.id) && mounted) {
      setState(() {});
    }
  }

  /// 最新节点（M7.1 物化复用：data 变更后定向重建——重读，不持有
  /// 陈旧快照；节点已删 → 回退入参快照，画布级结构事件会移除本卡片）。
  Node get _node => widget.host.graph.get(widget.node.id) ?? widget.node;

  /// 卡片体：成员节点自己的物化 Hook 渲染（kind='graph'）；
  /// 未物化 → 按需物化；未挂载/兜底 → 回退通用卡片体（永不空洞）。
  Widget _body() {
    final host = widget.host;
    if (!host.started) {
      // 测试兼容（无 UIManager）。
      return GenericNodeCardBody(node: _node, i18n: host.i18nService);
    }
    final hook =
        host.uiManager.hookFor(widget.node.id, 'graph') ??
        host.uiManager.materializeIfAbsent(widget.node.id, 'graph');
    if (hook == null) {
      return GenericNodeCardBody(node: _node, i18n: host.i18nService);
    }
    final sink = <Widget>[];
    hook.render(
      FlutterRenderContext(
        host: host,
        kind: 'graph',
        sink: sink,
      ),
    );
    if (sink.isEmpty) {
      // Hook 未挂载（占位）。
      return GenericNodeCardBody(node: _node, i18n: host.i18nService);
    }
    // 卡片体单 widget 约定（Hook 的 'graph' 形态 = 一个卡片体）。
    return sink.first;
  }

  @override
  Widget build(BuildContext context) {
    // M7.3 样式（判据② 外观直写）：尺寸定位 + 颜色/形态只在壳层应用，
    // 卡片体 Hook 渲染保持样式无关。
    final style = parseNodeStyle(
      widget.host.uiStateStore.get(canvasStyleKey(widget.node.id)),
    );
    var size = style?.size ?? defaultCardSize;
    if (style?.mode == NodeCardMode.circle) {
      // 圆形节点：取 min 宽高的方形（ClipOval 裁成圆）。
      final side = math.min(size.width, size.height);
      size = Size(side, side);
    }
    final cardColor =
        parseHexColor(style?.color) ??
        defaultColorForKind(
          widget.node.metadata['kind'],
          // P2-5：kind 默认配色亮度感知（暗色主题用暗色变体）。
          brightness: Theme.of(context).brightness,
        );
    return Positioned(
      left: widget.position.dx - size.width / 2,
      top: widget.position.dy - size.height / 2,
      width: size.width,
      height: size.height,
      child: NodeCard(
        node: _node,
        host: widget.host,
        body: _body(),
        cardColor: cardColor,
        mode: style?.mode,
        // M7.3 修正：拖拽反馈尺寸 = 样式尺寸（circle 已取方形）——
        // 反馈克隆源卡，拖拽不跳变/不变矩形。
        dragSize: size,
        onTap: widget.onTap,
        onConnectRequest: widget.onConnectRequest,
        onDragStart: widget.onDragStart,
        onDragUpdate: widget.onDragUpdate,
        onDragEnd: widget.onDragEnd,
      ),
    );
  }
}

/// 画布缩放控制组（M7.3：放大 / 缩小 / 适应视图）。
class _ZoomControls extends StatelessWidget {
  /// 注入 i18n 与三个回调。
  const _ZoomControls({
    required this.i18n,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  /// 国际化服务。
  final I18nService i18n;

  /// 放大回调。
  final VoidCallback onZoomIn;

  /// 缩小回调。
  final VoidCallback onZoomOut;

  /// 适应视图回调。
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: i18n.t('canvas.zoomOut'),
            onPressed: onZoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: i18n.t('canvas.zoomIn'),
            onPressed: onZoomIn,
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: i18n.t('canvas.zoomFit'),
            onPressed: onFit,
          ),
        ],
      ),
    );
  }
}

/// 网格背景绘制（画布视觉感知：间距 40 的淡色网格）。
class _GridPainter extends CustomPainter {
  /// 注入网格线颜色。
  _GridPainter({required this.color});

  /// 网格线颜色。
  final Color color;

  /// 网格间距（逻辑像素）。
  static const double _spacing = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.color != color;
}

/// 连接线绘制（两端卡片中心点连线；无向边）。
class _ConnectionPainter extends CustomPainter {
  /// 注入线段（世界坐标端点）。
  _ConnectionPainter({required this.lines});

  /// 线段集合。
  final List<(Offset, Offset)> lines;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final (from, to) in lines) {
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectionPainter oldDelegate) =>
      oldDelegate.lines != lines;
}
