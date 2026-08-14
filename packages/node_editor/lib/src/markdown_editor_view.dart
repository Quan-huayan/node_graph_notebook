/// MarkdownEditorView —— 笔记编辑/预览视图（M7 修正，Hook 承载 UI）。
///
/// EditorHook.render 挂载本视图（kind = 'open'——点击笔记 = 渲染其
/// Hook = 编辑器视图）。**服务注入**（commandBus——不依赖组合根 host）；
/// 无对话框外壳（HookView 的宿主提供容器）。保存 dispatch
/// `SaveNoteCommand`（写路径，00 不变量 4.4-1）；写后通知 → 重渲染。
/// 预览 = 简单 markdown 行解析（# 标题 / - 列表 / 普通文本）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'save_note.dart';

/// 笔记编辑视图。
class MarkdownEditorView extends StatefulWidget {
  /// 注入命令总线、目标节点与国际化服务（服务注入，M7 修正）。
  const MarkdownEditorView({
    super.key,
    required this.commandBus,
    required this.node,
    required this.i18n,
    this.padding = const EdgeInsets.all(16),
  });

  /// 命令总线。
  final CommandBus commandBus;

  /// 被编辑节点。
  final Node node;

  /// 国际化服务（壳层文案）。
  final I18nService i18n;

  /// 内边距（宿主容器适配）。
  final EdgeInsets padding;

  @override
  State<MarkdownEditorView> createState() => _MarkdownEditorViewState();
}

class _MarkdownEditorViewState extends State<MarkdownEditorView> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  bool _preview = false;
  late final void Function(WriteResult) _onWrite;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.node.title);
    _content = TextEditingController(text: widget.node.content ?? '');
    // 写后通知 → 刷新（外部保存时视图同步最新数据；dispose 关闭，
    // 03 §五 插件观察契约硬规则）。
    _onWrite = (_) {
      if (mounted) {
        setState(() {});
      }
    };
    (widget.commandBus as WriteNotifier).attach(_onWrite);
  }

  @override
  void dispose() {
    (widget.commandBus as WriteNotifier).detach(_onWrite);
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      // P1-4：Ctrl+S 保存（编辑器内焦点时生效——作用域 = 本视图）。
      Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _SaveIntent: CallbackAction<_SaveIntent>(
              onInvoke: (_) {
                _save();
                return null;
              },
            ),
          },
          child: Padding(
            padding: widget.padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
        Row(
          children: [
            Expanded(
              child: Text('${widget.i18n.t('node.edit')}「${widget.node.title}」'),
            ),
            // 编辑/预览切换（简单 markdown 渲染）。
            SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(widget.i18n.t('node.edit')),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(widget.i18n.t('editor.preview')),
                ),
              ],
              selected: <bool>{_preview},
              onSelectionChanged: (selection) =>
                  setState(() => _preview = selection.first),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          decoration: InputDecoration(
            labelText: widget.i18n.t('dialog.title'),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _preview
              ? _MarkdownPreview(text: _content.text)
              : TextField(
                  controller: _content,
                  expands: true,
                  // TextField 默认 maxLines = 1——expands 须显式 null。
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    labelText: widget.i18n.t('dialog.content'),
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _save,
            child: Text(widget.i18n.t('dialog.save')),
          ),
        ),
              ],
            ),
          ),
        ),
      );

  /// 保存（写路径：dispatch → Handler 落盘 → 写后通知）。
  ///
  /// 失败反馈（架构 §8：任何异常都有用户可见反馈，禁止静默失败）：
  /// 磁盘 IO 失败 → 可读文案（含检查建议）；其他异常 → 通用失败提示。
  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _showSnack(widget.i18n.t('dialog.titleRequired'));
      return;
    }
    try {
      await widget.commandBus.dispatch<SaveNoteCommand, SaveNoteResult>(
        SaveNoteCommand(
          nodeId: widget.node.id,
          title: title,
          content: _content.text,
        ),
      );
      _showSnack(widget.i18n.t('editor.saved'));
    } on IOException {
      _showSnack(widget.i18n.t('error.saveFailed'));
    } catch (error) {
      _showSnack('${widget.i18n.t('error.operationFailed')}: $error');
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }
}

/// Ctrl+S 保存意图（P1-4：编辑器内作用域）。
class _SaveIntent extends Intent {
  const _SaveIntent();
}

/// 简单 markdown 预览（M7 MVP：标题/列表/普通文本——不引第三方渲染器）。
class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = text.split('\n');
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              if (line.startsWith('# '))
                Text(
                  line.substring(2),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (line.startsWith('## '))
                Text(
                  line.substring(3),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (line.startsWith('- '))
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(line.substring(2))),
                    ],
                  ),
                )
              else if (line.trim().isEmpty)
                const SizedBox(height: 8)
              else
                Text(line),
          ],
        ),
      ),
    );
  }
}
