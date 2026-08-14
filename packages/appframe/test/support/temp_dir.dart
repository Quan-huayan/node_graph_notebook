/// 测试夹具：系统临时目录（自动清理）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory createTempDir(String prefix) {
  final dir = Directory.systemTemp.createTempSync('ngn_$prefix');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return dir;
}
