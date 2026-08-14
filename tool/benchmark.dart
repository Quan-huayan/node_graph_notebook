/// 10⁶ 基准脚本（architecture.md §9，CI nightly）。
///
/// 预算：
/// - 冷启动索引构建（目录枚举）< 2s（10⁶ 节点）
/// - 单次 save < 10ms
/// - 失效广播（HookIndex lookup）< 1ms（10⁶ 节点）
///
/// metadata 二级索引构建为一次性成本（架构 §6.3 只承诺内存可承受，
/// 无时间预算），单独报告实测值。
///
/// 用法：
/// ```bash
/// dart run tool/benchmark.dart                  # 默认 10⁶ 节点
/// dart run tool/benchmark.dart --nodes 10000    # 本地快速验证
/// ```
library;

import 'dart:io';

// 直接 import store 具体文件而非 barrel：dart CLI 不能编译依赖
// Flutter SDK 的编译单元（appframe 的 render/interaction 部分）。
import 'package:appframe/src/store/fs_graph.dart';
import 'package:appframe/src/store/stored_node.dart';
import 'package:core/core.dart';

void main(List<String> args) {
  var nodeCount = 1000000;
  final nodesArg = args.indexOf('--nodes');
  if (nodesArg >= 0 && nodesArg + 1 < args.length) {
    nodeCount = int.parse(args[nodesArg + 1]);
  }

  final root = Directory.systemTemp.createTempSync('ngn_benchmark');
  final sw = Stopwatch();
  var allPass = true;
  stdout.writeln('=== benchmark ===');
  stdout.writeln('nodes: $nodeCount');

  // ---- 1. save 吞吐（预算 <10ms/op）----
  final graph = FSTGraph(dataRoot: root);
  // warmup：排除 JIT 编译与目录创建首付成本（测后清理，不污染索引）。
  final warmupIds = <String>[];
  for (var w = 0; w < 10; w++) {
    final n = _node(0xffffff - w, -w);
    graph.save(n);
    warmupIds.add(n.id);
  }
  warmupIds.forEach(graph.delete);
  sw.reset();
  sw.start();
  for (var i = 0; i < nodeCount; i++) {
    graph.save(_node(i, i));
  }
  sw.stop();
  final saveMsPerOp = sw.elapsedMilliseconds / nodeCount;
  allPass = _report('save', saveMsPerOp, 10) && allPass;

  // ---- 2. 冷启动索引构建（目录枚举，预算 <2s）----
  final reopened = FSTGraph(dataRoot: root);
  sw.reset();
  sw.start();
  final index = reopened.scanIndex();
  sw.stop();
  allPass = _report('cold index build (enumeration)',
          sw.elapsedMilliseconds.toDouble(), 2000) &&
      allPass;
  stdout.writeln('  index entries: ${index.length}');

  // ---- 3. getByMetadata：一次性索引构建 + 查询（无预算，记录实测）----
  sw.reset();
  sw.start();
  final notes = reopened.getByMetadata('kind', 'note');
  sw.stop();
  allPass = _report('metadata index build + query (one-time)',
          sw.elapsedMilliseconds.toDouble(), double.infinity) &&
      allPass;
  stdout.writeln('  hits: ${notes.length}');

  // ---- 4. 失效广播：HookIndex lookup（预算 <1ms，10⁶ 物化）----
  final hookIndex = HookIndex();
  for (var i = 0; i < nodeCount; i++) {
    final id = i.toRadixString(16).padLeft(16, '0');
    hookIndex.materialize('hook_$i', id);
  }
  sw.reset();
  sw.start();
  for (var i = 0; i < 1000; i++) {
    hookIndex.lookup(i.toRadixString(16).padLeft(16, '0'));
  }
  sw.stop();
  final lookupMs = sw.elapsedMicroseconds / 1000; // 1000 次 → 单次均值
  allPass = _report('invalidation lookup (avg)', lookupMs, 1) && allPass;

  // ---- 清理 ----
  root.deleteSync(recursive: true);
  stdout.writeln('=== done (temp cleaned) ===');
  // CI 口径（05 纪律 12）：任一预算失败 → exit 1。
  exitCode = allPass ? 0 : 1;
}

/// 报告单项结果；返回是否在预算内（供 exit code 汇总）。
bool _report(String name, double ms, double budgetMs) {
  final ok = ms <= budgetMs;
  final budget = budgetMs.isInfinite ? 'no budget (one-time)' : 'budget <$budgetMs ms';
  stdout.writeln(
    '${ok ? 'PASS' : 'FAIL'}  $name: ${ms.toStringAsFixed(3)} ms ($budget)',
  );
  return ok;
}

StoredNode _node(int i, int metaI) {
  final id = i.toRadixString(16).padLeft(16, '0');
  return StoredNode(
    id: id,
    title: '节点 $metaI',
    content: '内容 $metaI',
    references: const <String, String>{},
    metadata: <String, dynamic>{
      'kind': metaI.isEven ? 'note' : 'folder',
      'i': metaI,
    },
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
