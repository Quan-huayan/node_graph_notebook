import 'package:flutter/material.dart';


/// 高亮文本组件
class HighlightText extends StatelessWidget {
  const HighlightText({
    required this.text,
    required this.query,
    this.maxLines,
  });

  final String text;
  final String? query;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    if (query == null || query!.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final matches = RegExp(query!, caseSensitive: false).allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final List<TextSpan> spans = [];
    int lastIndex = 0;

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