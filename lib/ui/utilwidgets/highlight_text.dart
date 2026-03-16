import 'package:flutter/material.dart';

/// 高亮文本组件
class HighlightText extends StatelessWidget {
  /// 创建高亮文本组件
  const HighlightText({required this.text, required this.query, this.maxLines});

  /// 要显示的文本
  final String text;
  
  /// 要高亮的查询字符串
  final String? query;
  
  /// 最大显示行数
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    if (query == null || query!.isEmpty) {
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final matches = RegExp(query!, caseSensitive: false).allMatches(text);

    if (matches.isEmpty) {
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    var lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            backgroundColor: Colors.yellow.shade200,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
