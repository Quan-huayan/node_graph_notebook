/// VaultManager 测试（M7.3 多仓库）：缺省补齐/config 读写、
/// 创建/切换/数据隔离、theme 状态迁移、删除守卫、重启恢复。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon.dart';

/// 装配管理器（空插件 + 幂等 seed：root 节点）。
VaultManager createManager(Directory base) => VaultManager(
    baseDir: base,
    pluginFactory: (_) => const <Plugin>[],
    seed: (host) {
      final now = DateTime.now();
      if (host.graph.get('root') == null) {
        host.graph.save(
          StoredNode(id: 'root', title: '根目录', createdAt: now, updatedAt: now),
        );
      }
    },
  );

void main() {
  late Directory base;

  setUp(() {
    base = Directory.systemTemp.createTempSync('ngn_vault');
    addTearDown(() {
      if (base.existsSync()) {
        base.deleteSync(recursive: true);
      }
    });
  });

  test('start：缺省仓库补齐（baseDir 零迁移）+ config 写入', () async {
    final manager = createManager(base);
    await manager.start();

    expect(manager.started, isTrue);
    expect(manager.vaults.length, 1);
    expect(manager.vaults.first.id, 'default');
    expect(manager.vaults.first.path, base.path);
    expect(manager.current.id, 'default');
    expect(manager.host.started, isTrue);
    // 缺省仓库 = baseDir 自身（旧 data/ 数据原地可用）。
    expect(manager.host.graph.get('root'), isNotNull);
    // config 已写。
    final config = File('${base.path}${Platform.pathSeparator}vaults.json');
    expect(config.existsSync(), isTrue);
  });

  test('创建仓库 + 切换 → 数据隔离（同名节点互不可见）', () async {
    final manager = createManager(base);
    await manager.start();
    // 缺省库写入 noteA。
    manager.host.graph.save(
      StoredNode(
        id: 'noteA',
        title: '缺省库的笔记',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final created = await manager.createVault('工作');
    expect(created.id, isNot('default'));
    expect(manager.current.id, created.id);
    // 新库无 noteA（数据隔离——独立数据根）。
    expect(manager.host.graph.get('noteA'), isNull);
    // 新库写入 noteB。
    manager.host.graph.save(
      StoredNode(
        id: 'noteB',
        title: '工作库的笔记',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // 切回缺省库。
    await manager.switchTo('default');
    expect(manager.host.graph.get('noteB'), isNull);
    expect(manager.host.graph.get('noteA'), isNotNull);
  });

  test('切换 → theme 壳层状态迁移', () async {
    final manager = createManager(base);
    await manager.start();
    manager.host.themeController
      ..setMode(AppThemeMode.dark)
      ..setTextScale(1.2)
      ..setFontFamily('serif');
    manager.host.i18nService.language = AppLanguage.en;

    await manager.createVault('工作');
    // 新 host 的 theme/i18n 复制旧值。
    expect(manager.host.themeController.mode, AppThemeMode.dark);
    expect(manager.host.themeController.textScale, 1.2);
    expect(manager.host.themeController.fontFamily, 'serif');
    expect(manager.host.i18nService.language, AppLanguage.en);
  });

  test('删除守卫：当前仓库不可删 / 默认仓库不可删 / 仅剩不可删', () async {
    final manager = createManager(base);
    await manager.start();
    // 仅剩一个 → 不可删。
    expect(() => manager.removeVault('default'), throwsA(isA<StateError>()));
    await manager.createVault('工作');
    // 当前（工作）不可删。
    expect(
      () => manager.removeVault(manager.current.id),
      throwsA(isA<StateError>()),
    );
    // 默认仓库（baseDir 自身，内含其余仓库与配置）→ 不可删。
    expect(() => manager.removeVault('default'), throwsA(isA<StateError>()));
  });

  test('移除非默认仓库 → 数据移入 .trash（不物理删除）', () async {
    final manager = createManager(base);
    await manager.start();
    final a = await manager.createVault('A');
    await manager.createVault('B'); // 切到 B，A 非当前可删。
    await manager.removeVault(a.id);
    expect(manager.vaults.length, 2);
    // 原目录已移走。
    expect(Directory(a.path).existsSync(), isFalse);
    // 回收站保留数据（可找回）。
    final trash = Directory('${base.path}${Platform.pathSeparator}.trash');
    expect(trash.existsSync(), isTrue);
    final entries = trash.listSync();
    expect(entries.any((e) => e.path.contains(a.id)), isTrue);
  });

  test('重启恢复：新管理器读 config（仓库列表 + 当前）', () async {
    final first = createManager(base);
    await first.start();
    await first.createVault('工作');

    final second = createManager(base);
    await second.start();
    expect(second.vaults.length, 2);
    expect(second.vaults.map((v) => v.id).toSet(), <String>{
      'default',
      first.vaults[1].id,
    });
    expect(second.current.id, first.vaults[1].id);
  });
}
