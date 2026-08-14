/// 依赖方向校验（04 §三 约束 1/3、architecture.md §2，CI 必跑）。
///
/// 检查两条：
/// 1. **声明一致性**：lib/ 的 `package:` import 必须出现在 pubspec
///    `dependencies`；test/ 必须出现在 `dependencies + dev_dependencies`。
/// 2. **分层方向**：工作区内包的 import 目标必须在方向表内
///    （core_data ← core ← appframe ← plugins/*；插件互相不依赖）。
///
/// 用法：
/// ```bash
/// dart run tool/check_imports.dart
/// ```
///
/// 违规 → 列清单并 exit 1（CI 失败）；干净 → 打印 PASS。
library;

import 'dart:io';

/// 分层方向表：包 → 允许依赖的工作区包集合。
///
/// - `app`（组合根）可依赖全部。
/// - `node_*` 插件只允许 core / core_data / appframe / plugon——
///   插件互相不依赖（04 §三 约束 3：通信走 Command）。
/// - `plugon` 为 vendored 自洽包。
const Map<String, Set<String>> directionAllow = <String, Set<String>>{
  'core_data': <String>{},
  'plugon': <String>{},
  'core': <String>{'core_data', 'plugon'},
  'appframe': <String>{'core', 'core_data', 'plugon'},
  // plugins（node_*）与 app 在 main() 里动态补全。
};

void main() {
  final root = Directory.current;
  final rootPubspec = File('${root.path}/pubspec.yaml');
  if (!rootPubspec.existsSync()) {
    stderr.writeln('错误：请在仓库根目录运行（找不到 pubspec.yaml）。');
    exitCode = 2;
    return;
  }

  // ---- 工作区包清单 ----
  final workspacePaths = _parseWorkspace(rootPubspec);
  final packages = <String, String>{}; // name → path
  for (final p in workspacePaths) {
    packages[Uri.parse(p).pathSegments.last] = p;
  }

  final violations = <String>[];
  for (final entry in packages.entries) {
    final name = entry.key;
    final dir = Directory('${root.path}/${entry.value}');
    if (!dir.existsSync()) {
      violations.add('${entry.value}: 目录不存在（workspace 指向失效）');
      continue;
    }
    final pubspec = _parseDeps(File('${dir.path}/pubspec.yaml'));
    final allowedLib = <String>{name, ...pubspec.dependencies};
    final allowedTest = <String>{name, ...pubspec.dependencies, ...pubspec.devDependencies};
    final direction = <String>{
      ...(directionAllow[name] ?? <String>{'core', 'core_data', 'appframe', 'plugon'}),
      // 组合根例外：app 装配全部插件。
      if (name == 'app') ...packages.keys,
    };

    for (final file in _dartFiles(dir)) {
      // Windows 分隔符归一：test/ 前缀判断与输出格式统一用 /。
      final rel = file.path
          .substring(dir.path.length + 1)
          .replaceAll('\\', '/');
      final inTest = rel.startsWith('test/');
      final allowed = inTest ? allowedTest : allowedLib;
      for (final imported in _imports(file)) {
        if (!packages.containsKey(imported)) {
          // 外部包：pub get 已强制声明一致性，此处仅补一道防线。
          if (!allowed.contains(imported)) {
            violations.add(
              '$name/$rel → 未声明外部依赖 package:$imported',
            );
          }
          continue;
        }
        if (imported == name) {
          continue; // 自引用（src 内部 import）合法。
        }
        if (!allowed.contains(imported)) {
          final section = inTest ? 'dev_dependencies' : 'dependencies';
          violations.add(
            '$name/$rel → package:$imported 未在 $section 声明',
          );
          continue;
        }
        if (!inTest && !direction.contains(imported)) {
          violations.add(
            '$name/$rel → package:$imported 违反分层方向'
            '（允许：$direction）',
          );
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('check_imports: PASS（${packages.length} 包扫描）');
    exitCode = 0;
  } else {
    stderr.writeln('check_imports: ${violations.length} 处违规：');
    violations.sort();
    violations.forEach((v) => stderr.writeln('  $v'));
    exitCode = 1;
  }
}

/// 解析根 pubspec 的 workspace 包路径列表。
List<String> _parseWorkspace(File pubspec) {
  final paths = <String>[];
  var inWorkspace = false;
  for (final raw in pubspec.readAsLinesSync()) {
    final line = raw.trimRight();
    if (line == 'workspace:') {
      inWorkspace = true;
      continue;
    }
    if (inWorkspace) {
      if (line.isEmpty || !line.startsWith(' ')) {
        break;
      }
      final m = RegExp(r'^\s*-\s*(.+?)\s*$').firstMatch(line);
      if (m != null) {
        paths.add(m.group(1)!);
      }
    }
  }
  if (paths.isEmpty) {
    stderr.writeln('错误：根 pubspec 未声明 workspace。');
    exit(2);
  }
  return paths;
}

/// 解析包 pubspec 的 dependencies / dev_dependencies 键集合。
({Set<String> dependencies, Set<String> devDependencies}) _parseDeps(
  File pubspec,
) {
  final deps = <String>{};
  final devDeps = <String>{};
  var section = '';
  for (final raw in pubspec.readAsLinesSync()) {
    final line = raw.trimRight();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    if (line == 'dependencies:' || line == 'dev_dependencies:') {
      section = line == 'dependencies:' ? 'deps' : 'dev';
      continue;
    }
    // 顶层键（零缩进）结束依赖节。
    if (!line.startsWith(' ')) {
      section = '';
      continue;
    }
    if (section.isEmpty || !line.startsWith('  ') || line.startsWith('   ')) {
      continue; // 只取一级缩进的键（依赖名行）。
    }
    final key = line.trimLeft().split(':').first.trim();
    if (key.isNotEmpty && RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(key)) {
      (section == 'deps' ? deps : devDeps).add(key);
    }
  }
  return (dependencies: deps, devDependencies: devDeps);
}

/// 递归收集包下 lib/ 与 test/ 的 Dart 文件。
List<File> _dartFiles(Directory dir) {
  final files = <File>[];
  for (final sub in <String>['lib', 'test']) {
    final d = Directory('${dir.path}/$sub');
    if (!d.existsSync()) {
      continue;
    }
    d.listSync(recursive: true).whereType<File>().where(
      (f) => f.path.endsWith('.dart'),
    ).forEach(files.add);
  }
  return files;
}

/// 提取文件里全部 `import/export 'package:x/...'` 的包名。
Set<String> _imports(File file) {
  final names = <String>{};
  final re = RegExp(r"^(?:import|export)\s+'package:([^/']+)/");
  for (final line in file.readAsLinesSync()) {
    final m = re.firstMatch(line.trim());
    if (m != null) {
      names.add(m.group(1)!);
    }
  }
  return names;
}
