/// 首启引导测试（P1-6）：
///
/// 首次启动（prefs 无 onboarding.shown）→ 弹引导对话框 → 关闭后标记
/// 落盘 → 下次启动不再弹。prefs null（测试/无持久化）→ 不弹。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('首启：弹引导 → 关闭标记落盘 → 二次启动不弹', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final root = Directory.systemTemp.createTempSync('ngn_onboarding');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root, prefs: prefs);
    final now = DateTime.now();
    host.graph.save(
      StoredNode(id: 'root', title: '根', createdAt: now, updatedAt: now),
    );

    // 首启：引导对话框出现。
    await tester.pumpWidget(NotebookApp(host: host, rootNodeId: 'root'));
    await tester.pumpAndSettle();
    expect(
      find.text(host.i18nService.t('onboarding.title')),
      findsOneWidget,
    );

    // 关闭 → 标记落盘。
    await tester.tap(find.text(host.i18nService.t('onboarding.dismiss')));
    await tester.pumpAndSettle();
    expect(prefs.getBool('onboarding.shown'), isTrue);
    expect(find.text(host.i18nService.t('onboarding.title')), findsNothing);

    // 二次启动（同一 prefs）→ 不弹。
    final second = HostRuntime(dataRoot: root, prefs: prefs);
    second.graph.save(
      StoredNode(id: 'root', title: '根', createdAt: now, updatedAt: now),
    );
    await tester.pumpWidget(NotebookApp(host: second, rootNodeId: 'root'));
    await tester.pumpAndSettle();
    expect(find.text(host.i18nService.t('onboarding.title')), findsNothing);
  });

  testWidgets('prefs null（测试/无持久化）→ 不弹引导', (tester) async {
    final root = Directory.systemTemp.createTempSync('ngn_onb_noprefs');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    host.graph.save(
      StoredNode(id: 'root', title: '根', createdAt: now, updatedAt: now),
    );

    await tester.pumpWidget(NotebookApp(host: host, rootNodeId: 'root'));
    await tester.pumpAndSettle();
    expect(find.text(host.i18nService.t('onboarding.title')), findsNothing);
  });
}
