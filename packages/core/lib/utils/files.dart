import 'dart:io';

/// 打开文件的辅助函数
Future<void> openFile(String filePath) async {
  try {
    if (Platform.isWindows) {
      // Windows: 使用 start 命令
      await Process.run('cmd', ['/c', 'start', '', filePath]);
    } else if (Platform.isMacOS) {
      // macOS: 使用 open 命令
      await Process.run('open', [filePath]);
    } else if (Platform.isLinux) {
      // Linux: 使用 xdg-open 命令
      await Process.run('xdg-open', [filePath]);
    } else {
      // 其他平台：尝试使用 url_launcher（需要额外实现）
      throw UnsupportedError('Unsupported platform');
    }
  } catch (e) {
    throw Exception('Failed to open file: $e');
  }
}
