import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_registry.dart';
import '../../../core/services/i18n.dart';
import '../../../core/utils/logger.dart';
import '../../../ui/bloc/ui_bloc.dart';
import '../../../ui/bloc/ui_event.dart';
import '../../../ui/bloc/ui_state.dart';
import '../bloc/graph_bloc.dart';
import '../bloc/node_bloc.dart';
import '../service/toolbar_settings_service.dart';

const _log = AppLogger('DraggableToolbar');

/// 可拖动工具栏
///
/// 支持：
/// - 拖动到任意位置
/// - 固定到预设位置（左上、右上、左下、右下）
/// - 展开/收起
/// - 位置设置持久化
/// - 窗口大小变化时自动调整固定位置
/// - 双击固定/取消固定
///
/// 架构说明：
/// - 可拖动工具栏是graph插件的自包含UI组件
/// - 只在graph插件内部使用
/// - 使用SharedPreferences持久化位置设置
/// - 通过Hook系统动态加载按钮
/// - 使用独立的hook point 'graph.toolbar' 避免与主工具栏按钮重复
class DraggableToolbar extends StatefulWidget {
  /// 构造函数
  const DraggableToolbar({super.key});

  @override
  State<DraggableToolbar> createState() => _DraggableToolbarState();
}

class _DraggableToolbarState extends State<DraggableToolbar> {
  /// 当前工具栏位置
  Offset _position = const Offset(16, 80);

  /// 是否正在拖动
  bool _isDragging = false;

  /// 是否固定到预设位置
  bool _isPinned = false;

  /// 固定位置（当isPinned为true时有效）
  ToolbarPosition _pinPosition = ToolbarPosition.topLeft;

  /// 上一次的窗口大小
  Size? _lastScreenSize;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  /// 加载保存的位置设置
  Future<void> _loadPosition() async {
    final setting = await ToolbarSettingsService.loadPosition();
    if (mounted) {
      // 延迟到布局完成后验证位置，确保屏幕尺寸已计算
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final screenSize = MediaQuery.of(context).size;
          final validatedPosition = _validatePosition(setting.position, screenSize);

          setState(() {
            _position = validatedPosition;
            _isPinned = setting.isPinned;
            _pinPosition = setting.pinPosition;
          });
        }
      });
    }
  }

  /// 验证位置是否在屏幕内，如果不在则返回默认位置
  ///
  /// [position] 要验证的位置
  /// [screenSize] 屏幕尺寸
  /// [sidebarWidth] 侧边栏宽度（用于避开侧边栏）
  /// 返回有效的位置坐标
  Offset _validatePosition(Offset position, Size screenSize, {double sidebarWidth = 0}) {
    const toolbarMargin = 16.0;
    const estimatedToolbarWidth = 200.0;
    const estimatedToolbarHeight = 400.0;

    // 检查位置是否在屏幕边界内
    // 左边界需要考虑侧边栏宽度和分隔线
    final minX = toolbarMargin + sidebarWidth + (sidebarWidth > 0 ? 5 : 0);
    final maxX = screenSize.width - estimatedToolbarWidth - toolbarMargin;
    const minY = toolbarMargin + kToolbarHeight; // 避开AppBar
    final maxY = screenSize.height - estimatedToolbarHeight - toolbarMargin;

    // 如果位置完全在屏幕外，重置到默认位置（避开侧边栏）
    if (position.dx < minX || position.dx > maxX ||
        position.dy < minY || position.dy > maxY) {
      _log.info('Position out of bounds, resetting to default');
      return Offset(minX, 80);
    }

    // 确保位置部分可见（至少有一部分在屏幕内）
    final clampedX = position.dx.clamp(minX, maxX);
    final clampedY = position.dy.clamp(minY, maxY);

    if (clampedX != position.dx || clampedY != position.dy) {
      _log.info('Position adjusted to fit on screen');
      return Offset(clampedX, clampedY);
    }

    return position;
  }

  /// 保存位置设置
  Future<void> _savePosition() async {
    final setting = ToolbarPositionSetting(
      position: _position,
      isPinned: _isPinned,
      pinPosition: _pinPosition,
    );
    await ToolbarSettingsService.savePosition(setting);
  }

  /// 切换固定状态
  void _togglePin() {
    setState(() {
      _isPinned = !_isPinned;
      if (_isPinned) {
        _pinPosition = _calculateNearestPinPosition();
      }
    });
    _savePosition();
  }

  /// 计算最近的固定位置
  ToolbarPosition _calculateNearestPinPosition() {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;
    final toolbarX = _position.dx;
    final toolbarY = _position.dy;

    if (toolbarX < centerX && toolbarY < centerY) {
      return ToolbarPosition.topLeft;
    } else if (toolbarX >= centerX && toolbarY < centerY) {
      return ToolbarPosition.topRight;
    } else if (toolbarX < centerX && toolbarY >= centerY) {
      return ToolbarPosition.bottomLeft;
    } else {
      return ToolbarPosition.bottomRight;
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<UIBloc, UIState>(
      builder: (context, uiState) {
        final i18n = I18n.of(context);
        final screenSize = MediaQuery.of(context).size;

        _handleScreenSizeChange(screenSize);

        var widgetPosition = _isPinned
            ? _getPinnedPosition(screenSize, sidebarWidth: uiState.isSidebarOpen ? uiState.sidebarWidth : 0)
            : _position;

        // 当侧边栏打开时，如果工具栏在左侧，向右偏移以避开侧边栏
        // 偏移量包含侧边栏宽度和分隔线宽度
        if (uiState.isSidebarOpen && widgetPosition.dx < uiState.sidebarWidth) {
          widgetPosition = Offset(
            widgetPosition.dx + uiState.sidebarWidth + 5, // 5 是分隔线宽度
            widgetPosition.dy,
          );
        }

        return Positioned(
          left: widgetPosition.dx,
          top: widgetPosition.dy,
          child: GestureDetector(
            onPanStart: (_) {
              if (!_isPinned) {
                setState(() {
                  _isDragging = true;
                });
              }
            },
            onPanUpdate: (details) {
              if (!_isPinned) {
                setState(() {
                  final newPosition = _position + details.delta;
                  // 确保新位置在屏幕边界内（考虑侧边栏）
                  final sidebarWidth = uiState.isSidebarOpen ? uiState.sidebarWidth : 0.0;
                  _position = _validatePosition(newPosition, screenSize, sidebarWidth: sidebarWidth);
                });
              }
            },
            onPanEnd: (_) {
              if (_isDragging) {
                setState(() {
                  _isDragging = false;
                });
                _savePosition();
              }
            },
            onDoubleTap: _togglePin,
            child: Card(
              elevation: _isDragging ? 8 : 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToolbarHeader(context, uiState, i18n),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            uiState.isToolbarExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          tooltip: i18n.t('Collapse/Expand Toolbar'),
                          onPressed: () {
                            context.read<UIBloc>().add(const UIToggleToolbarEvent());
                          },
                        ),
                        if (uiState.isToolbarExpanded) ...[
                          ..._buildToolbarHooks(context),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

  /// 处理窗口大小变化
  void _handleScreenSizeChange(Size screenSize) {
    if (_lastScreenSize == null) {
      _lastScreenSize = screenSize;
      return;
    }

    final sizeChanged = _lastScreenSize!.width != screenSize.width ||
        _lastScreenSize!.height != screenSize.height;

    if (sizeChanged) {
      // 直接更新_lastScreenSize，不需要setState
      // screenSize的变化会触发build，所以无需手动触发重建
      _lastScreenSize = screenSize;
    }
  }

  /// 构建工具栏头部
  Widget _buildToolbarHeader(
    BuildContext context,
    UIState uiState,
    I18n i18n,
  ) => Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(
            _isPinned ? Icons.push_pin : Icons.drag_handle,
            size: 16,
            color: Colors.grey,
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: _isPinned ? 'Double-click to unpin' : 'Double-click to pin',
            child: Icon(
              _isPinned ? Icons.location_on : Icons.location_off,
              size: 16,
              color: _isPinned ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
        ],
      ),
    );

  /// 获取固定位置坐标
  ///
  /// [screenSize] 屏幕尺寸
  /// [sidebarWidth] 侧边栏宽度（用于避开侧边栏）
  Offset _getPinnedPosition(Size screenSize, {double sidebarWidth = 0}) {
    const margin = 16.0;
    const estimatedWidth = 200.0;
    const estimatedHeight = 200.0;
    const dividerWidth = 5.0; // 分隔线宽度

    switch (_pinPosition) {
      case ToolbarPosition.topLeft:
        return Offset(margin + sidebarWidth + (sidebarWidth > 0 ? dividerWidth : 0), 80);
      case ToolbarPosition.topRight:
        return Offset(
          screenSize.width - estimatedWidth - margin,
          80,
        );
      case ToolbarPosition.bottomLeft:
        return Offset(
          margin + sidebarWidth + (sidebarWidth > 0 ? dividerWidth : 0),
          screenSize.height - estimatedHeight - margin,
        );
      case ToolbarPosition.bottomRight:
        return Offset(
          screenSize.width - estimatedWidth - margin,
          screenSize.height - estimatedHeight - margin,
        );
    }
  }

  /// 构建工具栏Hook按钮
  List<Widget> _buildToolbarHooks(BuildContext context) {
    final hookWrappers = hookRegistry.getHookWrappers('graph.toolbar');

    return hookWrappers.map((hookWrapper) {
      final hook = hookWrapper.hook;
      final hookContext = MainToolbarHookContext(
        data: {
          'buildContext': context,
          'graphBloc': context.read<GraphBloc>(),
          'nodeBloc': context.read<NodeBloc>(),
        },
        pluginContext: hookWrapper.parentPlugin?.context,
        hookAPIRegistry: hookRegistry.apiRegistry,
      );

      if (hook.isVisible(hookContext)) {
        return hook.render(hookContext);
      }
      return null;
    }).whereType<Widget>().toList().reversed.toList();
  }
}
