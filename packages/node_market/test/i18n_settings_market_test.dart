/// i18n / settings / market 插件测试（M7，01 拍板 #38-40）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_i18n/node_i18n.dart'; // I18nPlugin（语言设置条目）。
import 'package:node_market/node_market.dart';
import 'package:node_settings/node_settings.dart';
import 'package:plugon/plugon.dart';

void main() {
  late HostRuntime host;

  setUp(() async {
    final root = Directory.systemTemp.createTempSync('ngn_i18n');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    host = HostRuntime(dataRoot: root);
    await host.start(
      plugins: <Plugin>[I18nPlugin(), SettingsPlugin(), MarketPlugin()],
      rootNodeId: 'root',
    );
  });

  test('i18n：zh 默认 + en 切换 + 缺失键回退', () {
    final i18n = host.serviceProvider.get<I18nService>();
    expect(i18n.t('app.title'), '节点图谱笔记');
    i18n.setLanguage(AppLanguage.en);
    expect(i18n.t('app.title'), 'Node Graph Notebook');
    expect(i18n.t('no.such.key'), 'no.such.key'); // 缺失键回退键本身。
  });

  test('settings：主题切换（壳层 ThemeController，M7.2 E3）', () {
    final theme = host.serviceProvider.get<ThemeController>();
    expect(theme.mode, AppThemeMode.system);
    theme.setMode(AppThemeMode.dark);
    expect(theme.mode, AppThemeMode.dark);
  });

  test('market：已装插件列表（组合根装配）', () {
    // 宿主加载了 i18n/settings/market 三插件。
    expect(host.loadedPlugins.map((p) => p.metadata.id), <String>{
      'com.example.i18n',
      'com.example.settings',
      'com.example.market',
    });
  });
}
