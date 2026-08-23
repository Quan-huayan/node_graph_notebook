/// MarkdownView —— markdown 渲染视图（A1：Obsidian 阅读模式子集）。
///
/// 块级 → widget 树；行内 span → 按样式拆 Text（链接为可点击 GestureDetector，
/// 点击行为 = [onLinkTap]（宿主注入）；缺省 = 复制到剪贴板 + SnackBar——
/// 零新依赖（无 url_launcher，01 纪律）。
///
/// 长文：MVP 单滚动视图（调用方置于可滚动容器）；10⁶ 级懒渲染归
/// architecture.md [计划]，不在此断言。
library;

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'markdown_parser.dart';

/// 渲染 markdown 文本。
class MarkdownView extends StatelessWidget {
  /// 构造。
  const MarkdownView({super.key, required this.text, this.onLinkTap, this.i18n});

  /// markdown 源文本。
  final String text;

  /// 链接点击回调（null = 缺省：复制 URL + SnackBar）。
  final void Function(String url)? onLinkTap;

  /// 国际化服务（链接点击 SnackBar 文案，05 纪律 7；null = 英文兜底）。
  final I18nService? i18n;

  @override
  Widget build(BuildContext context) {
    final blocks = const MarkdownParser().parse(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final block in blocks) _blockWidget(context, block),
      ],
    );
  }

  /// 块 → widget。
  Widget _blockWidget(BuildContext context, MdBlock block) => switch (block) {
    MdHeading(:final level, :final inline) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: _wrap(context, inline, _headingStyle(context, level)),
    ),
    MdParagraph(:final inline) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _wrap(context, inline, Theme.of(context).textTheme.bodyMedium),
    ),
    MdList(:final ordered, :final items) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var i = 0; i < items.length; i++)
            _listItem(context, ordered, i + 1, items[i]),
        ],
      ),
    ),
    MdQuote(:final inline) => Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 3,
          ),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.35),
      ),
      child: _wrap(context, inline, Theme.of(context).textTheme.bodyMedium),
    ),
    MdCodeBlock(:final code) => Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        code,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
        ),
      ),
    ),
    MdHr() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1),
    ),
    MdTable(:final rows) => _table(context, rows),
  };

  /// 列表项（标记 + 文本 + 嵌套子块）。
  Widget _listItem(
    BuildContext context,
    bool ordered,
    int index,
    MdListItem item,
  ) {
    final marker = ordered
        ? '$index. '
        : item.checked != null
        ? ''
        : '• ';
    final content = _wrap(context, item.text, Theme.of(context).textTheme.bodyMedium);
    final row = Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (ordered || (item.checked == null && marker.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                marker,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (item.checked != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Checkbox(
                value: item.checked,
                onChanged: null,
                visualDensity: VisualDensity.compact,
              ),
            ),
          Expanded(child: content),
        ],
      ),
    );
    if (item.children.isEmpty) {
      return row;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        row,
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final child in item.children)
                _blockWidget(context, child),
            ],
          ),
        ),
      ],
    );
  }

  /// 表格（简化：全部单元格 bodyMedium，首行加粗）。
  Widget _table(BuildContext context, List<MdTableRow> rows) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final headerStyle = style?.copyWith(fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        children: <TableRow>[
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: r == 0
                  ? BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    )
                  : null,
              children: <Widget>[
                for (final cell in rows[r].cells)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: _wrap(context, cell, r == 0 ? headerStyle : style),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// 标题样式（h1 最大 → h6 最小，全部加粗）。
  TextStyle? _headingStyle(BuildContext context, int level) {
    final theme = Theme.of(context).textTheme;
    final base = switch (level) {
      1 => theme.headlineSmall,
      2 => theme.titleLarge,
      3 => theme.titleMedium,
      4 => theme.titleSmall,
      5 => theme.bodyLarge,
      _ => theme.bodyMedium,
    };
    return base?.copyWith(fontWeight: FontWeight.bold);
  }

  /// 行内 span → Wrap（Text 各自换行，加粗/斜体/删除线/行内码/链接分拆）。
  Widget _wrap(
    BuildContext context,
    List<MdSpan> spans,
    TextStyle? style,
  ) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.start,
    children: <Widget>[
      for (final span in spans) ..._spanWidgets(context, span, style),
    ],
  );

  /// span → widget 列表（嵌套 span 递归展开）。
  List<Widget> _spanWidgets(
    BuildContext context,
    MdSpan span,
    TextStyle? style,
  ) => switch (span) {
    MdText(:final text) => <Widget>[Text(text, style: style)],
    MdBold(:final children) => <Widget>[
      for (final child in children)
        ..._spanWidgets(
          context,
          child,
          style?.copyWith(fontWeight: FontWeight.bold),
        ),
    ],
    MdItalic(:final children) => <Widget>[
      for (final child in children)
        ..._spanWidgets(
          context,
          child,
          style?.copyWith(fontStyle: FontStyle.italic),
        ),
    ],
    MdStrike(:final children) => <Widget>[
      for (final child in children)
        ..._spanWidgets(
          context,
          child,
          style?.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: style.color,
          ),
        ),
    ],
    MdCode(:final code) => <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          code,
          style: style?.copyWith(fontFamily: 'monospace'),
        ),
      ),
    ],
    MdLink(:final text, :final url) => <Widget>[
      GestureDetector(
        onTap: () => _onLink(context, url),
        child: Text(
          text,
          style: style?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    ],
  };

  /// 链接点击（宿主回调优先；缺省复制 + SnackBar——零新依赖）。
  void _onLink(BuildContext context, String url) {
    final handler = onLinkTap;
    if (handler != null) {
      handler(url);
      return;
    }
    Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      final message = i18n == null
          ? 'Link copied: $url' // 无 i18n 兜底（05 纪律 7：不硬编码中文）。
          : i18n!.t('editor.linkCopied').replaceFirst('%s', url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}