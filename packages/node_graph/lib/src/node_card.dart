/// NodeCard —— 画布节点卡片壳（M7.1：交互壳 + 注入卡片体）。
///
/// 交互（对齐旧 node_menu/node_metadata_dialog 资产的新架构形态）：
/// - 左键拖动 = 移动卡片（即时 Draggable，判据② 位置直写）
/// - 拖另一卡片到本卡片附近 = 建立连接（就近判定在 GraphCanvas
///   _resolveDrop——卡片 DragTarget 只提供命中高亮，不消费 drop）
/// - 右键菜单：查看内容 / 编辑（标题+内容）/ 断开所有连接 / 删除
/// - 点击 = 查看内容
///
/// M7.1（画布成员 Hook 化）：**卡片体由成员节点自己的 Hook 渲染**
/// （kind='graph'，_PositionedCard 注入）——本壳只承载画布语义
/// （定位/拖拽/连接/菜单），不代替节点呈现（Hook Tree 02 §3.2）。
/// 右键用 Listener 自实现（不参与手势 arena——GestureDetector 的
/// SecondaryTap 在桌面事件流被 arena 竞争吞掉，实测失效；与画布
/// 双击同一模式）。写操作一律走 CommandBus（00 不变量 4.4-1）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'connection_concept.dart';
import 'node_commands.dart';
import 'node_dialogs.dart';
import 'node_style_dialog.dart';

/// 卡片尺寸（画布世界坐标的固定单元；默认源 = appframe defaultCardSize，
/// M7.3 样式尺寸覆盖时按节点样式）。
const Size cardSize = defaultCardSize;

/// 画布节点卡片（交互壳）。
class NodeCard extends StatelessWidget {
  /// 注入节点、宿主、卡片体与交互回调。
  ///
  /// [body] 卡片体（Hook 渲染结果或回退体——画布不代替节点呈现）。
  /// [onConnectRequest] 连接判定回调（拖 A 到本卡片附近时宿主判定）。
  /// [cardColor] 卡片底色（null = 按 kind 默认配色）；[mode] 形态
  /// （circle = 圆形裁剪，M7.3 样式——只在壳层应用，卡片体不变）。
  const NodeCard({
    super.key,
    required this.node,
    required this.host,
    required this.onTap,
    required this.body,
    this.cardColor,
    this.mode,
    this.onConnectRequest,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragStart,
    this.dragSize,
  });

  /// 所呈现节点。
  final Node node;

  /// 宿主组合根（命令总线/结构存储）。
  final HostRuntime host;

  /// 点击查看内容（宿主对话框）。
  final VoidCallback onTap;

  /// 卡片体（成员节点 Hook 的 kind='graph' 渲染，或回退体）。
  final Widget body;

  /// 卡片底色（样式，M7.3）。
  final Color? cardColor;

  /// 形态（样式，M7.3）。
  final NodeCardMode? mode;

  /// 连接判定回调（draggedId + 落点全局坐标；null = 画布未接线）。
  final void Function(String draggedId, Offset globalPoint)? onConnectRequest;

  /// 拖拽中实时预览回调（卡片/连线跟随；null = 画布未接线）。
  final void Function(String nodeId, Offset globalPoint)? onDragUpdate;

  /// 拖拽结束回调（清理预览；null = 画布未接线）。
  final void Function(String nodeId)? onDragEnd;

  /// 抓取起点回调（主键按下；卡片位移 = 指针位移的锚点）。
  final void Function(String nodeId, Offset globalPoint)? onDragStart;

  /// 拖拽反馈尺寸（样式尺寸，circle 已取方形；null = 默认卡尺寸）。
  /// M7.3 修正：反馈 = 样式克隆——旧实现固定默认尺寸，圆形节点一拖
  /// 就变矩形（"一点也不圆"）。
  final Size? dragSize;

  @override
  Widget build(BuildContext context) =>
      // 连接接收 DragTarget（命中高亮；drop 统一由宿主 _resolveDrop 判定——
      // 卡片 DragTarget 不消费，避免吞掉画布移动语义）。
      DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != node.id,
        onAcceptWithDetails: (details) =>
            onConnectRequest?.call(details.data, details.offset),
        builder: (context, candidates, rejected) {
          final highlight = candidates.isNotEmpty;
          return Listener(
            // 右键菜单（不参与手势 arena，100% 触发）。
            onPointerDown: (event) {
              if (event.kind == PointerDeviceKind.mouse &&
                  event.buttons == kSecondaryMouseButton) {
                _showMenu(context, event.position);
              } else if (event.buttons == kPrimaryButton) {
                // 抓取起点（拖拽锚点：卡片位移 = 指针位移）。
                onDragStart?.call(node.id, event.position);
              }
            },
            child: Draggable<String>(
              data: node.id,
              feedback: _feedback(context),
              childWhenDragging: _card(context, opacity: 0.4, highlight: false),
              child: _card(context, opacity: 1, highlight: highlight),
              onDragUpdate: (details) =>
                  onDragUpdate?.call(node.id, details.globalPosition),
              onDragEnd: (_) => onDragEnd?.call(node.id),
            ),
          );
        },
      );

  /// 卡片本体（拖拽中/接收高亮可配置；内容 = 注入的卡片体）。
  /// M7.3 样式：cardColor 底色 + circle 圆形裁剪（只在壳层，卡片体不变）。
  Widget _card(
    BuildContext context, {
    required double opacity,
    required bool highlight,
  }) {
    final theme = Theme.of(context);
    Widget card = Card(
      elevation: 2,
      color: cardColor,
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(8), child: body),
      ),
    );
    if (mode == NodeCardMode.circle) {
      // 圆形节点：裁剪为圆（定位尺寸由画布壳按 min 宽高控制）。
      card = ClipOval(child: card);
    }
    return Opacity(opacity: opacity, child: card);
  }

  /// 拖拽反馈（浮动卡片）——**样式克隆**（尺寸/底色/形态随源卡片）。
  ///
  /// M7.3 修正记录：旧实现固定默认尺寸、无底色——文件夹节点
  /// （kind 默认 amber 50）拖拽时反馈闪出一张白卡（"闪色"）；圆形
  /// 样式节点拖拽反馈变 180×96 矩形（"一点也不圆"）。现按源卡片
  /// 样式克隆，拖拽所见 = 源卡同款。
  Widget _feedback(BuildContext context) {
    final size = dragSize ?? cardSize;
    Widget card = Card(
      elevation: 6,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(node.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
    if (mode == NodeCardMode.circle) {
      card = ClipOval(child: card);
    }
    return Material(
      color: Colors.transparent,
      child: SizedBox(width: size.width, height: size.height, child: card),
    );
  }

  /// 右键菜单（对齐旧 node_menu.dart 交互）。
  Future<void> _showMenu(BuildContext context, Offset position) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: <PopupMenuEntry<String>>[
        // M7.2（i18n 壳层）：菜单文案走语言包。
        PopupMenuItem<String>(
          value: 'view',
          child: Text(host.i18nService.t('node.view')),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Text(host.i18nService.t('node.edit')),
        ),
        PopupMenuItem<String>(
          value: 'style',
          child: Text(host.i18nService.t('node.style')),
        ),
        PopupMenuItem<String>(
          value: 'disconnect',
          child: Text(host.i18nService.t('node.disconnect')),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(host.i18nService.t('node.delete')),
        ),
      ],
    );
    if (!context.mounted) {
      return;
    }
    switch (action) {
      case 'view':
        onTap();
      case 'edit':
        await _edit(context);
      case 'style':
        await _style(context);
      case 'disconnect':
        await _disconnectAll(context);
      case 'delete':
        await _delete(context);
    }
  }

  /// 样式编辑（判据② 外观直写：set/remove，不发结构事件；画布经
  /// UIStateStore 观察者通道刷新）。
  Future<void> _style(BuildContext context) async {
    final result = await showDialog<NodeStyle>(
      context: context,
      builder: (context) => NodeStyleDialog(
        i18n: host.i18nService,
        initial: parseNodeStyle(host.uiStateStore.get(canvasStyleKey(node.id))),
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }
    if (result.isEmpty) {
      host.uiStateStore.remove(canvasStyleKey(node.id));
    } else {
      host.uiStateStore.set(canvasStyleKey(node.id), result.toJson());
    }
  }

  /// 编辑（标题 + 内容 → UpdateNodeCommand，判据①）。
  Future<void> _edit(BuildContext context) async {
    final form = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => NodeEditDialog(
        node: node,
        dialogTitle: '${host.i18nService.t('node.edit')}「${node.title}」',
        i18n: host.i18nService,
      ),
    );
    if (form == null || !context.mounted) {
      return;
    }
    try {
      await host.commandBus.dispatch<UpdateNodeCommand, UpdateNodeResult>(
        UpdateNodeCommand(
          nodeId: node.id,
          title: form['title'] as String,
          content: form['content'] as String,
        ),
      );
    } on IOException {
      _showError(context, host.i18nService.t('error.saveFailed'));
    } catch (error) {
      _showError(context, '${host.i18nService.t('error.operationFailed')}: $error');
    }
  }

  /// 删除（确认 → DeleteNodeCommand，级联清理关系实例与位置键）。
  Future<void> _delete(BuildContext context) async {
    // P1-5：确认对话框共用壳（appframe showDeleteNodeConfirm）。
    final confirmed = await showDeleteNodeConfirm(
      context,
      i18n: host.i18nService,
      title: node.title,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await host.commandBus.dispatch<DeleteNodeCommand, DeleteNodeResult>(
        DeleteNodeCommand(nodeId: node.id),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(host.i18nService.t('node.deleted')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } on IOException {
      _showError(context, host.i18nService.t('error.saveFailed'));
    } catch (error) {
      _showError(context, '${host.i18nService.t('error.operationFailed')}: $error');
    }
  }

  /// 断开所有连接（删除引用本节点的连接实例）。
  Future<void> _disconnectAll(BuildContext context) async {
    final connections = host.graph
        .getAll()
        .where(
          (n) =>
              const ConnectionConcept().validate(n) &&
              n.references.values.contains(node.id),
        )
        .toList();
    try {
      for (final conn in connections) {
        await host.commandBus.dispatch<DeleteNodeCommand, DeleteNodeResult>(
          DeleteNodeCommand(nodeId: conn.id),
        );
      }
    } on IOException {
      _showError(context, host.i18nService.t('error.saveFailed'));
      return;
    } catch (error) {
      _showError(context, '${host.i18nService.t('error.operationFailed')}: $error');
      return;
    }
    if (connections.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${host.i18nService.t('node.disconnected')} ${connections.length}',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 失败反馈（架构 §8：禁止静默失败）。
  void _showError(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

/// 通用卡片体（回退呈现，M7.1：Hook 未提供 'graph' 形态时——永不空洞）。
///
/// 图标按 metadata kind 映射（无概念依赖，04 §三 约束 3；AI 节点等
/// 新 kind 在此映射，语义分发归宿主）。各插件的卡片体（NoteCardView
/// /AICardView/FolderCardView）提供 'graph' 形态后，本回退体承接
/// 兜底 / Lua 动态 Concept 等未实现 'graph' 呈现的节点。
class GenericNodeCardBody extends StatelessWidget {
  /// 注入节点与语言包（M7.2：i18n 是壳层概念，文案走 t()）。
  const GenericNodeCardBody({super.key, required this.node, required this.i18n});

  /// 所呈现节点。
  final Node node;

  /// 语言服务（壳层注入）。
  final I18nService i18n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              node.metadata['kind'] == 'folder'
                  ? Icons.folder
                  : node.metadata['kind'] == 'ai'
                  ? Icons.smart_toy
                  : Icons.description,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Text(
            node.content?.trim().replaceAll(RegExp(r'\s+'), ' ') ??
                i18n.t('card.emptyContent'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
