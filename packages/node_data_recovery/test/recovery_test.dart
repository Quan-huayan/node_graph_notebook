/// 数据恢复插件测试（M7，01 拍板 #35）：
///
/// 备份（sidecar 复制到 data/backups/<时间戳>）；校验（可解析 + 引用
/// 完整——悬空引用检出）；修复（损坏 sidecar 删除 + Graph 索引清理）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_data_recovery/node_data_recovery.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_recovery');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'root',
        title: '根目录',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(id: 'noteA', title: '笔记A', createdAt: now, updatedAt: now),
    ].forEach(host.graph.save);
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[RecoveryPlugin(servicesProvider: resolveServices)],
      rootNodeId: 'root',
    );
  });

  test('Backup：sidecar 复制到 backups/<时间戳>', () async {
    final result = await host.commandBus.dispatch<BackupCommand, BackupResult>(
      const BackupCommand(),
    );
    expect(result.backupPath, contains('backups'));
    final backupDir = Directory(result.backupPath);
    expect(backupDir.existsSync(), isTrue);
    // 备份含节点 sidecar（root + noteA）。
    final backups = backupDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.node.json'))
        .toList();
    expect(backups, hasLength(2));
  });

  test('Verify：健康库零问题', () async {
    final result = await host.commandBus.dispatch<VerifyCommand, VerifyResult>(
      const VerifyCommand(),
    );
    expect(result.issues, isEmpty);
  });

  test('Verify：悬空引用检出', () async {
    // 手工写入引用不存在的 sidecar（绕过 Graph 写路径——校验是文件级）。
    final sidecarDir = host.graph.sidecar.storeDir;
    final partition = Directory('${sidecarDir.path}${Platform.pathSeparator}xx')
      ..createSync(recursive: true);
    File(
      '${partition.path}${Platform.pathSeparator}xx1.node.json',
    ).writeAsStringSync(
      jsonEncode(<String, dynamic>{
        'id': 'xx1',
        'title': '悬空',
        'references': <String, String>{'related': 'ghost'},
      }),
    );
    final result = await host.commandBus.dispatch<VerifyCommand, VerifyResult>(
      const VerifyCommand(),
    );
    expect(result.issues.any((i) => i.contains('ghost')), isTrue);
  });

  test('R9 P0 修复：Verify 对合法但非 Map 的 JSON 判结构异常（不击穿）', () async {
    // audit #4：第二遍 `as Map` 的 TypeError 曾击穿 Handler；补类型化捕获后
    // 两遍均判「结构异常」（合法 JSON 数组/字符串非 Map）。
    final sidecarDir = host.graph.sidecar.storeDir;
    final partition = Directory('${sidecarDir.path}${Platform.pathSeparator}zz')
      ..createSync(recursive: true);
    File(
      '${partition.path}${Platform.pathSeparator}zz1.node.json',
    ).writeAsStringSync(jsonEncode(<int>[1, 2, 3]));
    final result = await host.commandBus.dispatch<VerifyCommand, VerifyResult>(
      const VerifyCommand(),
    );
    expect(result.issues.any((i) => i.contains('结构异常')), isTrue);
  });

  test('Repair：损坏 sidecar 删除 + Graph 索引清理', () async {
    final sidecarDir = host.graph.sidecar.storeDir;
    final partition = Directory('${sidecarDir.path}${Platform.pathSeparator}xx')
      ..createSync(recursive: true);
    File(
      '${partition.path}${Platform.pathSeparator}xx2.node.json',
    ).writeAsStringSync('{ 这不是合法 JSON');
    final result = await host.commandBus.dispatch<RepairCommand, RepairResult>(
      const RepairCommand(),
    );
    expect(result.repairedNodeIds, <String>{'xx2'});
    expect(
      File(
        '${partition.path}${Platform.pathSeparator}xx2.node.json',
      ).existsSync(),
      isFalse,
    );
    // 健康节点不受影响。
    expect(host.graph.get('noteA'), isNotNull);
  });

  test('R9 P0 修复：Repair 对合法但非 Map 的 JSON 判损坏删除（不崩溃）', () async {
    // audit #5：`as Map` TypeError 曾击穿修复 Handler（本应删除该损坏
    // sidecar）；补 on TypeError 后按 corrupt 判定删除 + Graph 索引清理。
    final sidecarDir = host.graph.sidecar.storeDir;
    final partition = Directory('${sidecarDir.path}${Platform.pathSeparator}zz')
      ..createSync(recursive: true);
    final target = File(
      '${partition.path}${Platform.pathSeparator}zz2.node.json',
    );
    target.writeAsStringSync(jsonEncode('just a string'));
    final result = await host.commandBus.dispatch<RepairCommand, RepairResult>(
      const RepairCommand(),
    );
    expect(result.repairedNodeIds, <String>{'zz2'});
    expect(target.existsSync(), isFalse);
    // 健康节点不受影响。
    expect(host.graph.get('noteA'), isNotNull);
  });

  test('P2-5 契约：Backup 含 ui-state.json（外观状态完整快照）', () async {
    // 先落一个外观键（FSUIStateStore 写盘 → ui-state.json 存在）。
    host.uiStateStore.set('position.graph.noteA', const <String, dynamic>{
      'x': 10.0,
      'y': 20.0,
    });
    final result = await host.commandBus.dispatch<BackupCommand, BackupResult>(
      const BackupCommand(),
    );
    final uiState = File(
      '${result.backupPath}${Platform.pathSeparator}ui-state.json',
    );
    expect(uiState.existsSync(), isTrue);
    expect(uiState.readAsStringSync(), contains('position.graph.noteA'));
  });

  test('P2-5 契约：Verify → Repair → Verify 零问题（损坏闭环）', () async {
    final sidecarDir = host.graph.sidecar.storeDir;
    final partition = Directory('${sidecarDir.path}${Platform.pathSeparator}yy')
      ..createSync(recursive: true);
    File(
      '${partition.path}${Platform.pathSeparator}yy1.node.json',
    ).writeAsStringSync('{ 损坏');
    final before = await host.commandBus.dispatch<VerifyCommand, VerifyResult>(
      const VerifyCommand(),
    );
    expect(before.issues, isNotEmpty);
    await host.commandBus.dispatch<RepairCommand, RepairResult>(
      const RepairCommand(),
    );
    final after = await host.commandBus.dispatch<VerifyCommand, VerifyResult>(
      const VerifyCommand(),
    );
    expect(after.issues, isEmpty);
  });

  test('P2-5 契约：Repair 幂等（无损坏 → 零修复）', () async {
    final first = await host.commandBus.dispatch<RepairCommand, RepairResult>(
      const RepairCommand(),
    );
    expect(first.repairedNodeIds, isEmpty);
  });
}
