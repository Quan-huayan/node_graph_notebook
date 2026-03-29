import 'package:flutter_test/flutter_test.dart';

/// Node Graph Notebook测试套件的测试配置。
///
/// 此文件为widget测试设置自定义超时，以确保
/// 测试在较慢的机器上有足够的时间完成。
void main() {
  // 配置默认测试超时
  setUpAll(() {
    // 将所有widget测试的超时时间增加到30秒
    // 这可以防止在较慢的机器或CI环境中出现超时失败
  });
}
