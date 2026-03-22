import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/services/i18n.dart';
import 'package:provider/provider.dart';

void main() {
  group('I18n Provider Integration', () {
    testWidgets('应该能正确创建 ChangeNotifierProvider', (tester) async {
      final i18n = I18n();

      await tester.pumpWidget(
        ChangeNotifierProvider<I18n>.value(
          value: i18n,
          child: const MaterialApp(
            home: Scaffold(
              body: _TestWidget(),
            ),
          ),
        ),
      );

      // 等待 Widget 构建完成
      await tester.pumpAndSettle();

      // 验证 I18n 可以通过 Provider 访问
      expect(find.byType(_TestWidget), findsOneWidget);

      // 验证翻译功能正常
      expect(i18n.t('Settings'), 'Settings'); // 英文
    });

    testWidgets('应该能正确监听语言变化', (tester) async {
      final i18n = I18n();

      await tester.pumpWidget(
        ChangeNotifierProvider<I18n>.value(
          value: i18n,
          child: const MaterialApp(
            home: Scaffold(
              body: _ListeningTestWidget(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 初始语言应该是英文
      expect(find.text('Settings'), findsOneWidget);

      // 切换到中文
      await i18n.switchLanguage('zh');
      // 使用 pump 而不是 pumpAndSettle，避免无限等待
      await tester.pump();

      // 现在应该显示中文
      expect(find.text('设置'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}

/// 测试 Widget - 验证可以访问 I18n
class _TestWidget extends StatelessWidget {
  const _TestWidget();

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return Text(i18n.t('Settings'));
  }
}

/// 监听变化的测试 Widget
class _ListeningTestWidget extends StatefulWidget {
  const _ListeningTestWidget();

  @override
  State<_ListeningTestWidget> createState() => _ListeningTestWidgetState();
}

class _ListeningTestWidgetState extends State<_ListeningTestWidget> {
  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    return Text(i18n.t('Settings'));
  }
}
