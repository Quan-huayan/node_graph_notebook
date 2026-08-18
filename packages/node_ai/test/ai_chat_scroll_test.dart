/// AIChatView 自动滚动测试（UX：回复可见性）。
///
/// - 打开会话默认滚到最新消息（对话入口显示最近内容，而非最早消息）
/// - 新消息落盘（写后通知）→ 若用户位于底部则自动跟随滚动
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_ai/node_ai.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_ai_scroll');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  /// 会话内容：多条长消息（超出可视高度 → maxScrollExtent > 0）。
  String _longContent() {
    final buffer = StringBuffer('## 对话（与「笔记」）\n\n');
    for (var i = 0; i < 6; i++) {
      buffer
        ..writeln('**用户**: 第 $i 条问题，' + '很长很长的内容' * 8)
        ..writeln('继续行 $i')
        ..writeln()
        ..writeln('**AI**: 第 $i 条回复，' + '解答解答解答' * 8)
        ..writeln()
        ..writeln();
    }
    return buffer.toString();
  }

  Future<HostRuntime> seed() async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'ai',
        title: 'AI 助手',
        metadata: const <String, dynamic>{'kind': 'ai'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'chat',
        title: '会话',
        content: _longContent(),
        references: const <String, String>{'ai': 'ai', 'source': 'note'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    await host.start(plugins: <Plugin>[AiPlugin()], rootNodeId: 'ai');
    return host;
  }

  /// 消息列表（第二个 ListView——第一个是会话列表）。
  Finder _messageList() => find
      .descendant(of: find.byType(AIChatView), matching: find.byType(ListView))
      .at(1);

  ScrollPosition _position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: _messageList(), matching: find.byType(Scrollable)),
      )
      .position;

  testWidgets('打开会话 → 自动滚动到底部（最新消息可见）', (tester) async {
    final host = await seed();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 500,
            child: AIChatView(
              graph: host.graph,
              commandBus: host.commandBus,
              aiNodeId: 'ai',
              config: host.serviceProvider.get<AIProviderConfig>(),
              i18n: host.i18nService,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // 首帧后的强制滚动：post-frame 触发动画 → pumpAndSettle 等动画
    // 与物理钳制全部稳定（内容高度首帧回落时位置回正）。
    await tester.pumpAndSettle();

    final position = _position(tester);
    expect(position.maxScrollExtent, greaterThan(0)); // 内容确实溢出。
    expect(
      (position.maxScrollExtent - position.pixels).abs(),
      lessThan(8), // 已滚到底。
    );
  });

  testWidgets('新消息落盘 → 位于底部时自动跟随滚动', (tester) async {
    final host = await seed();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 500,
            child: AIChatView(
              graph: host.graph,
              commandBus: host.commandBus,
              aiNodeId: 'ai',
              config: host.serviceProvider.get<AIProviderConfig>(),
              i18n: host.i18nService,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // 追加新消息（写后通知 → 底部跟随）。
    await host.commandBus.dispatch<AppendMessageCommand, AppendMessageResult>(
      AppendMessageCommand(chatId: 'chat', message: '新的一条消息，' + '新的内容' * 10),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final position = _position(tester);
    expect(
      (position.maxScrollExtent - position.pixels).abs(),
      lessThan(8), // 新消息可见。
    );
  });
}
