import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 结构守卫：锁定 lib/core 的分层契约——
/// 核心层永远是纯 Dart，不得导入 Flutter，也不得反向依赖 flutter 适配层。
/// 任何人把 Flutter 依赖塞进 core，此测试立即变红。
void main() {
  test('lib/core 下所有 .dart 文件不导入 package:flutter', () {
    final coreDir = Directory('lib/core');
    final dartFiles = coreDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    expect(dartFiles.isNotEmpty, isTrue, reason: 'core 目录不应为空');
    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      expect(
        content.contains('package:flutter'),
        isFalse,
        reason: '${file.path} 不得导入 Flutter',
      );
      expect(
        content.contains("import 'package:plugon/flutter"),
        isFalse,
        reason: '${file.path} 不得反向依赖 flutter 适配层',
      );
    }
  });
}
