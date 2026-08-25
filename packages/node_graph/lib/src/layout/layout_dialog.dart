/// CanvasLayoutDialog —— 布局对话框（M7.3）：选择算法 → dispatch
/// ApplyLayoutCommand（长任务 Handler 计算 + UIStateStore 位置键直写，
/// 画布观察者通道自动刷新）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'layout_algorithms.dart';
import 'layout_commands.dart';

/// 布局对话框。
class CanvasLayoutDialog extends StatefulWidget {
  /// 注入宿主。
  const CanvasLayoutDialog({super.key, required this.host});

  /// 宿主组合根。
  final HostRuntime host;

  @override
  State<CanvasLayoutDialog> createState() => _CanvasLayoutDialogState();
}

class _CanvasLayoutDialogState extends State<CanvasLayoutDialog> {
  LayoutAlgorithm _algorithm = LayoutAlgorithm.force;

  @override
  Widget build(BuildContext context) {
    final i18n = widget.host.i18nService;
    return AlertDialog(
      title: Text(i18n.t('layout.title')),
      content: RadioGroup<LayoutAlgorithm>(
        groupValue: _algorithm,
        onChanged: (value) => setState(() => _algorithm = value ?? _algorithm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final algorithm in LayoutAlgorithm.values)
              RadioListTile<LayoutAlgorithm>(
                title: Text(_label(algorithm)),
                value: algorithm,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(i18n.t('dialog.cancel')),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await widget.host.commandBus
                  .dispatch<ApplyLayoutCommand, ApplyLayoutResult>(
                    ApplyLayoutCommand(algorithm: _algorithm),
                  );
            } on CycleError {
              // 布局 = 判据②外观直写（无结构引用写，正常不触发环校验）——
              // 防御性类型化捕获（R9 已知失败在前），文案统一操作失败。
              _showFailure('error.operationFailed');
              return;
            } on StateError {
              // 已知类型化失败（命令路由/前置校验）→ 用户可见反馈，
              // 原始 error 不上屏（R11 统一裁决）。
              _showFailure('error.operationFailed');
              return;
            } catch (error) {
              // UI 边界兜底豁免（R9 注释，docs/review 总览 P0-1 裁决）：用户入口的
              // 回调不得泄漏未捕获异常（05 纪律 8：任何失败须有用户可见反馈）；
              // 未知编程错误保留诊断痕迹（debugPrint），原始 error 文本不上屏。
              debugPrint('<应用布局> failed: $error');
              _showFailure('error.operationFailed');
              return;
            }
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(i18n.t('layout.applied')),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          child: Text(i18n.t('dialog.save')),
        ),
      ],
    );
  }

  /// 失败反馈（架构 §8：禁止静默失败；R11：原始 error 不上屏，
  /// 统一走翻译键文案）。
  void _showFailure(String key) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.host.i18nService.t(key)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _label(LayoutAlgorithm algorithm) {
    final i18n = widget.host.i18nService;
    switch (algorithm) {
      case LayoutAlgorithm.force:
        return i18n.t('layout.force');
      case LayoutAlgorithm.grid:
        return i18n.t('layout.grid');
      case LayoutAlgorithm.tree:
        return i18n.t('layout.tree');
    }
  }
}
