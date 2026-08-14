/// 对话消息序列化测试（01 拍板 #30：消息 = chat content markdown）：
///
/// appendMessage 追加（空记录带头部 / 已有记录续写）；
/// parseMessages 解析（角色切分 / 手工续行合并 / 抗外部编辑——不崩溃）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_ai/node_ai.dart';

void main() {
  group('appendMessage', () {
    test('空记录 → 带头部写入首条消息', () {
      final content = appendMessage(
        content: null,
        role: ChatRole.user,
        text: '你好',
        chatTitle: '第一篇笔记',
      );
      expect(content, contains('## 对话（与「第一篇笔记」）'));
      expect(content, contains('**用户**: 你好'));
    });

    test('已有记录 → 续写（保留历史）', () {
      final first = appendMessage(
        content: null,
        role: ChatRole.user,
        text: '你好',
        chatTitle: '笔记',
      );
      final second = appendMessage(
        content: first,
        role: ChatRole.ai,
        text: '回复你',
        chatTitle: '笔记',
      );
      expect(second, contains('**用户**: 你好'));
      expect(second, contains('**AI**: 回复你'));
      // 消息顺序：用户在前，AI 在后。
      expect(
        second.indexOf('**用户**: 你好'),
        lessThan(second.indexOf('**AI**: 回复你')),
      );
    });

    test('消息文本去首尾空白', () {
      final content = appendMessage(
        content: null,
        role: ChatRole.user,
        text: '  带空格  ',
        chatTitle: '笔记',
      );
      expect(content, contains('**用户**: 带空格'));
    });
  });

  group('parseMessages', () {
    test('角色切分', () {
      final content = appendMessage(
        content: appendMessage(
          content: null,
          role: ChatRole.user,
          text: '你好',
          chatTitle: '笔记',
        ),
        role: ChatRole.ai,
        text: '回复',
        chatTitle: '笔记',
      );
      final messages = parseMessages(content);
      expect(messages, hasLength(2));
      expect(messages[0].role, ChatRole.user);
      expect(messages[0].text, '你好');
      expect(messages[1].role, ChatRole.ai);
      expect(messages[1].text, '回复');
    });

    test('手工续行合并进前一条消息', () {
      const content = '## 对话（与「笔记」）\n\n**用户**: 第一行\n第二行\n\n**AI**: 回复';
      final messages = parseMessages(content);
      expect(messages, hasLength(2));
      expect(messages[0].text, '第一行\n第二行');
    });

    test('空/无消息记录 → 空列表', () {
      expect(parseMessages(null), isEmpty);
      expect(parseMessages(''), isEmpty);
      expect(parseMessages('   '), isEmpty);
    });

    test('抗外部编辑：无法识别的行不崩溃', () {
      final messages = parseMessages('随便写的文本\n**用户**: 正常消息\n残破前缀: 无角色');
      expect(messages, hasLength(1));
      expect(messages[0].role, ChatRole.user);
    });
  });
}
