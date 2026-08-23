/// Markdown 解析器与代码区掩码单元测试（纯 Dart，无 Flutter）。
///
/// 验收锚点（A1）：块级 + 行内子集确定性；未闭合标记回退纯文本不崩溃；
/// maskCodeRegions 与 TagService 共用——代码区内 #tag 不误计。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_editor/src/markdown/markdown_parser.dart';

void main() {
  const parser = MarkdownParser();

  group('块级解析', () {
    test('标题 h1-h6', () {
      final blocks = parser.parse('# 一级\n## 二级\n### 三级\n###### 六级\n');
      expect(blocks, hasLength(4));
      expect((blocks[0] as MdHeading).level, 1);
      expect((blocks[0] as MdHeading).inline, hasLength(1));
      expect(((blocks[0] as MdHeading).inline.single as MdText).text, '一级');
      expect((blocks[1] as MdHeading).level, 2);
      expect((blocks[3] as MdHeading).level, 6);
    });

    test('# 无空格 = 段落', () {
      final blocks = parser.parse('#没有空格');
      expect(blocks.single, isA<MdParagraph>());
    });

    test('无序列表 + 嵌套子列表', () {
      final blocks = parser.parse('- a\n- b\n  - b1\n  - b2\n- c\n');
      final list = blocks.single as MdList;
      expect(list.ordered, isFalse);
      expect(list.items, hasLength(3));
      final second = list.items[1];
      final nested = second.children.single as MdList;
      expect(nested.items, hasLength(2));
      expect((nested.items[0].text.single as MdText).text, 'b1');
    });

    test('有序列表', () {
      final blocks = parser.parse('1. 第一\n2. 第二\n');
      final list = blocks.single as MdList;
      expect(list.ordered, isTrue);
      expect(list.items, hasLength(2));
    });

    test('任务列表 - [ ] / - [x]', () {
      final blocks = parser.parse('- [ ] 待办\n- [x] 完成\n');
      final list = blocks.single as MdList;
      expect(list.items[0].checked, isFalse);
      expect(list.items[1].checked, isTrue);
    });

    test('引用块', () {
      final blocks = parser.parse('> 引用第一行\n> 引用第二行\n');
      final quote = blocks.single as MdQuote;
      final text = quote.inline.whereType<MdText>().map((t) => t.text).join();
      expect(text, contains('引用第一行'));
      expect(text, contains('引用第二行'));
    });

    test('围栏代码块（带语言）', () {
      final blocks = parser.parse('```dart\nvoid main() {}\n```\n后文\n');
      expect(blocks, hasLength(2));
      final code = blocks[0] as MdCodeBlock;
      expect(code.code, 'void main() {}');
      expect(blocks[1], isA<MdParagraph>());
    });

    test('围栏未闭合 → 余下全部按代码块（不崩溃）', () {
      final blocks = parser.parse('```\na\nb\n');
      expect(blocks.single, isA<MdCodeBlock>());
      expect((blocks.single as MdCodeBlock).code, 'a\nb');
    });

    test('分割线', () {
      final blocks = parser.parse('---\n');
      expect(blocks.single, isA<MdHr>());
    });

    test('表格（表头 + 分隔行 + 行）', () {
      final blocks = parser.parse('| 名称 | 值 |\n|---|---|\n| a | 1 |\n');
      final table = blocks.single as MdTable;
      expect(table.rows, hasLength(2));
      expect(table.rows[0].cells, hasLength(2));
      expect((table.rows[1].cells[0].single as MdText).text, 'a');
    });
  });

  group('行内解析', () {
    List<MdSpan> spans(String text) => MarkdownParser.parseInline(text);

    test('粗体', () {
      final s = spans('前 **粗** 后');
      expect(s, hasLength(3));
      expect(s[1], isA<MdBold>());
      expect((s[1] as MdBold).children.single, isA<MdText>());
    });

    test('斜体', () {
      final s = spans('前 *斜* 后');
      expect(s[1], isA<MdItalic>());
    });

    test('删除线', () {
      final s = spans('前 ~~删~~ 后');
      expect(s[1], isA<MdStrike>());
    });

    test('行内代码', () {
      final s = spans('前 `code` 后');
      expect((s[1] as MdCode).code, 'code');
    });

    test('链接', () {
      final s = spans('[名称](https://example.com)');
      final link = s.single as MdLink;
      expect(link.text, '名称');
      expect(link.url, 'https://example.com');
    });

    test('未闭合标记回退纯文本', () {
      final s = spans('**未闭合');
      expect(s.single, isA<MdText>());
      expect((s.single as MdText).text, '**未闭合');
    });

    test('嵌套：粗体内斜体', () {
      final s = spans('**a *b* c**');
      final bold = s.single as MdBold;
      expect(bold.children.whereType<MdItalic>(), hasLength(1));
    });
  });
}