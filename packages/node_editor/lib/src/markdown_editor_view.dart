/// MarkdownEditorView —— 笔记编辑/预览视图（M7 修正，Hook 承载 UI）。
///
/// EditorHook.render 挂载本视图（kind = 'open'——点击笔记 = 渲染其
/// Hook = 编辑器视图）。保存 dispatch `SaveNoteCommand`（写路径，00
/// 不变量 4.4-1）；写后通知 → 重渲染。
///
/// A（Obsidian 补齐，可选参数——无宿主场景（单插件测试）行为不变）：
/// - 富 markdown 预览（A1：MarkdownView——块级 + 行内子集）
/// - 标签 chips（A2：TagService 解析 content 的 `#tag`；点击 → 带标签
///   过滤的搜索请求（shellSignals.requestTagSearch））
/// - 反向链接区（A3：BacklinkService——图引用 linked + 内容提及
///   unlinked，点击打开对端节点）
/// - 字数统计（C4：会话态，随输入即时更新）
/// - 导出为 Markdown 菜单（A4：动作名查 ToolbarActionRegistry 的
///   targeted 动作 'converter.exportNote'——插件互不依赖，未注册隐藏）
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'markdown/markdown_view.dart';
import 'save_note.dart';

/// 笔记编辑视图。
class MarkdownEditorView extends StatefulWidget {
  /// 注入命令总线、目标节点与国际化服务（服务注入，M7 修正）。
  /// [host] 与知识服务为可选——A2/A3/A4 扩展；null = 相应区块隐藏。
  const MarkdownEditorView({
    super.key,
    required this.commandBus,
    required this.node,
    required this.i18n,
    this.padding = const EdgeInsets.all(16),
    this.host,
    this.tagService,
    this.backlinkService,
    this.shellSignals,
    this.onExportNote,
  });

  /// 命令总线。
  final CommandBus commandBus;

  /// 被编辑节点。
  final Node node;

  /// 国际化服务（壳层文案）。
  final I18nService i18n;

  /// 内边距（宿主容器适配）。
  final EdgeInsets padding;

  /// 宿主组合根（A2/A3 打开/导出接线；null = 隐藏扩展区块）。
  final HostRuntime? host;

  /// 标签服务（A2 chips；null = 隐藏）。
  final TagService? tagService;

  /// 反链服务（A3；null = 隐藏）。
  final BacklinkService? backlinkService;

  /// 壳层信号（A2 chip 点击 → 带标签搜索；null = chips 不可点）。
  final ShellSignals? shellSignals;

  /// 导出单节点动作（A4：查 registry 的 targeted 'converter.exportNote'；
  /// null = 隐藏导出菜单——converter 插件未加载）。
  final void Function(BuildContext context, String nodeId)? onExportNote;

  @override
  State<MarkdownEditorView> createState() => _MarkdownEditorViewState();
}

class _MarkdownEditorViewState extends State<MarkdownEditorView> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _propsTags;
  bool _preview = false;
  bool _showBacklinks = true;
  bool _showProps = true;
  late final void Function(WriteResult) _onWrite;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.node.title);
    _content = TextEditingController(text: widget.node.content ?? '');
    // C2：属性面板——初始值 = 当前 metadata（tags 列表），
    // 编辑后整体写回（标签为主字段，其余 metadata 只读展示）。
    final tags = widget.node.metadata['tags'];
    _propsTags = TextEditingController(
      text: tags is List ? tags.whereType<String>().join(', ') : (tags?.toString() ?? ''),
    );
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

  /// 字数统计（会话态：空白折叠分词；空 = 0）。
  int get _wordCount {
    final text = _content.text.trim();
    if (text.isEmpty) {
      return 0;
    }
    return text.split(RegExp(r'\s+')).length;
  }

  /// 当前内容标签（A2：TagService 解析——未保存的编辑也即时可见）。
  Set<String> get _tags {
    final service = widget.tagService;
    if (service == null) {
      return const <String>{};
    }
    return TagService.parseTags(_content.text).toSet();
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
            // C4：字数（会话态）。
            Text(
              '${widget.i18n.t('editor.words')}：$_wordCount',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(width: 8),
            // A4：导出为 Markdown（动作未注册 → 隐藏）。
            if (widget.onExportNote != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: widget.i18n.t('node.more'),
                onSelected: (value) {
                  if (value == 'export') {
                    widget.onExportNote!(context, widget.node.id);
                  }
                },
                itemBuilder: (context) => <PopupMenuItem<String>>[
                  PopupMenuItem<String>(
                    value: 'export',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.upload_outlined, size: 18),
                      title: Text(widget.i18n.t('editor.exportMarkdown')),
                    ),
                  ),
                ],
              ),
            // 编辑/预览切换（富 markdown 渲染，A1）。
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
        // A2：标签 chips（内容编辑即时解析）。
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              children: <Widget>[
                for (final tag in _tags)
                  ActionChip(
                    label: Text('#$tag'),
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.shellSignals == null
                        ? null
                        : () => widget.shellSignals!.requestTagSearch(tag),
                  ),
              ],
            ),
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
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: MarkdownView(text: _content.text, i18n: widget.i18n),
                  ),
                )
              : TextField(
                  controller: _content,
                  expands: true,
                  // TextField 默认 maxLines = 1——expands 须显式 null。
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => setState(() {}), // 字数/标签即时更新。
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
        // C2：属性区（metadata 编辑——标签主字段，重启保持，判据②）。
        _propertiesSection(context),
        // A3：反向链接区（图引用 + 内容提及）。
        if (widget.backlinkService != null) _backlinksSection(context),
              ],
            ),
          ),
        ),
      );

  /// C2 属性区（metadata 编辑——标签主字段；保存走 UpdateNodeCommand
  /// 写路径（判据①），对偶撤销恢复旧 metadata；重启保持（判据②）。
  Widget _propertiesSection(BuildContext context) => _SectionCard(
      title: widget.i18n.t('properties.title'),
      expanded: _showProps,
      onToggle: () => setState(() => _showProps = !_showProps),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _propsTags,
              decoration: InputDecoration(
                labelText: widget.i18n.t('properties.tags'),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saveProps,
            child: Text(widget.i18n.t('properties.save')),
          ),
        ],
      ),
    );

  /// 保存属性（标签列表 → metadata['tags'] 整体写回）。
  Future<void> _saveProps() async {
    final tags = _propsTags.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final metadata = Map<String, dynamic>.from(widget.node.metadata)
      ..['tags'] = tags;
    try {
      await widget.commandBus.dispatch<UpdateNodeCommand, UpdateNodeResult>(
        UpdateNodeCommand(nodeId: widget.node.id, metadata: metadata),
      );
      _showSnack(widget.i18n.t('properties.saved'));
    } on StateError {
      // 已知失败（UpdateNode/core）：目标节点不存在/未注册命令 → 类型化
      // 捕获，文案走 t() 键（R11：原始 $error 不上屏）。
      _showSnack(widget.i18n.t('error.operationFailed'));
    } on CycleError {
      // 已知失败（core 环校验命中）→ 类型化捕获。
      _showSnack(widget.i18n.t('error.operationFailed'));
    } catch (error) {
      // UI 边界兜底豁免（R9 注释，docs/review 总览 P0-1 裁决）：用户入口的
      // 回调不得泄漏未捕获异常（05 纪律 8：任何失败须有用户可见反馈）；
      // 未知编程错误保留诊断痕迹（debugPrint），原始 error 文本不上屏。
      debugPrint('UpdateNode failed: $error');
      _showSnack(widget.i18n.t('error.operationFailed'));
    }
  }
  Widget _backlinksSection(BuildContext context) {
    final nodeId = widget.node.id;
    final linked = widget.backlinkService!.linkedBacklinks(nodeId);
    final unlinked = widget.backlinkService!.unlinkedMentions(nodeId);
    return _SectionCard(
      title: widget.i18n.t('backlinks.title'),
      expanded: _showBacklinks,
      onToggle: () => setState(() => _showBacklinks = !_showBacklinks),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _subGroup(
            context,
            widget.i18n.t('backlinks.linked'),
            linked,
            nodeId,
          ),
          const SizedBox(height: 4),
          _subGroup(
            context,
            widget.i18n.t('backlinks.unlinked'),
            unlinked,
            nodeId,
          ),
        ],
      ),
    );
  }

  /// 子组（图引用/提及）列表。
  Widget _subGroup(
    BuildContext context,
    String label,
    List<Node> nodes,
    String selfNodeId,
  ) {
    final host = widget.host;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        if (nodes.isEmpty)
          Text(
            widget.i18n.t('backlinks.empty'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (final node in nodes)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link, size: 16),
              title: Text(node.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: host == null
                  ? null
                  : () => openNodeDialog(context, host, node.id),
            ),
      ],
    );
  }

  /// 保存（写路径：dispatch → Handler 落盘 → 写后通知）。
  ///
  /// 失败反馈（架构 §8：任何异常都有用户可见反馈，禁止静默失败）：
  /// 磁盘 IO 失败 → error.saveFailed；已知命令失败（StateError/CycleError）
  /// → 类型化捕获 + t() 键文案；未知编程错误 → 兜底 + debugPrint（R9 豁免）。
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
    } on StateError {
      // 已知失败（SaveNote/core）：目标节点不存在/未注册命令 → 类型化
      // 捕获，文案走 t() 键（R11：原始 $error 不上屏）。
      _showSnack(widget.i18n.t('error.operationFailed'));
    } on CycleError {
      // 已知失败（core 环校验命中）→ 类型化捕获。
      _showSnack(widget.i18n.t('error.operationFailed'));
    } catch (error) {
      // UI 边界兜底豁免（R9 注释，docs/review 总览 P0-1 裁决）：用户入口的
      // 回调不得泄漏未捕获异常（05 纪律 8：任何失败须有用户可见反馈）；
      // 未知编程错误保留诊断痕迹（debugPrint），原始 error 文本不上屏。
      debugPrint('SaveNote failed: $error');
      _showSnack(widget.i18n.t('error.operationFailed'));
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

/// 折叠区块卡片（反链区外壳）。
class _SectionCard extends StatelessWidget {
  /// 构造。
  const _SectionCard({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  /// 标题。
  final String title;

  /// 展开态。
  final bool expanded;

  /// 切换回调。
  final VoidCallback onToggle;

  /// 内容。
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Row(
              children: <Widget>[
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
          if (expanded) ...[
            const Divider(height: 8),
            child,
          ],
        ],
      ),
    ),
  );
}

/// Ctrl+S 保存意图（P1-4：编辑器内作用域）。
class _SaveIntent extends Intent {
  const _SaveIntent();
}