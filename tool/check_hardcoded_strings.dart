/// UI 层硬编码中文字符串检查（05 纪律 7 + P1-3 验收，CI 必跑）。
///
/// 算法：状态机剥离注释（`//`、`/* */`），仅统计**字符串字面量**内的
/// CJK——注释里的中文（项目注释语言）不算；Dart 标识符不含 CJK，
/// 故命中即字符串字面量。raw/三引号/转义/插值均有状态覆盖。
///
/// 豁免政策（P1-3 验收豁免 + 2026-08-13 全量裁决，05 §四 P2-1 记录）：
/// **只查 UI 文案**；数据/协议层豁免——种子数据、模型元数据
/// （Concept/Plugin 的 name/description）、内部错误消息（不直达用户，
/// UI 已按 P0-3 包装为 t() 文案）、序列化/协议文本（Lua 协议、
/// chat 落盘格式、导出文件头、诊断输出）、vendored 第三方。
///
/// 用法：
/// ```bash
/// dart run tool/check_hardcoded_strings.dart
/// ```
///
/// 违规 → 列清单并 exit 1；干净 → 打印 PASS。
library;

import 'dart:io';

/// 豁免清单（工作区相对路径；条目 = 文件，或目录前缀 = 整目录豁免）。
const List<String> allowlist = <String>[
  // —— 种子数据（空库播种标题/内容：用户数据，非 UI 文案）——
  'packages/app/lib/main.dart',
  // 缺省仓库名（seed 同类数据）+ 仓库 StateError。
  'packages/appframe/lib/src/host/vault_manager.dart',
  // —— 翻译字典本体（en 对照表无中文，无需豁免）——
  'packages/appframe/lib/src/i18n/translations.dart',
  // —— 内部错误消息（StateError/CycleError/UnimplementedError——
  // 不直达用户，UI 按 P0-3 包装为 t() 文案）——
  'packages/core/lib/src',
  'packages/core_data/lib/src/models/concept.dart', // 默认 drop 拒绝原因
  'packages/appframe/lib/src/command/create_toolbar_button.dart',
  'packages/appframe/lib/src/interaction/drag_controller.dart', // 拒绝原因
  'packages/appframe/lib/src/store/sidecar_store.dart', // 损坏兜底：FallbackNode 合成标题 + 异常消息
  'packages/appframe/lib/src/store/fs_ui_state_store.dart', // 损坏 ui-state.json 兜底诊断日志（R9 内部错误，UI 已走 t()）
  'packages/node_graph/lib/src/node_commands.dart',
  'packages/node_graph/lib/src/canvas_widget.dart', // 画布操作失败 debugPrint 诊断日志（R9 内部错误，UI 文案走 t()）
  'packages/node_graph/lib/src/layout/layout_dialog.dart', // 布局失败诊断日志（内部错误）
  'packages/node_graph/lib/src/node_card.dart', // 卡片操作失败诊断日志（内部错误）
  'packages/node_folder/lib/src/move_nodes.dart',
  'packages/node_folder/lib/src/folder_create.dart', // 目标文件夹不存在（内部错误）
  'packages/node_editor/lib/src/save_note.dart',
  // —— 序列化/协议文本 ——
  'packages/node_converter/lib/src/converter_handlers.dart', // 导出文件头
  'packages/node_ai/lib/src/ai_provider.dart', // Mock 回复
  'packages/node_ai/lib/src/function_calling', // 工具协议文案
  'packages/node_ai/lib/src/chat_handlers.dart', // 默认提示+工具调用日志（写入 chat 落盘）
  'packages/node_ai/lib/src/chat_messages.dart', // chat markdown 序列化标记
  'packages/node_lua/lib/src/lua_engine.dart', // 'error:' 协议 + 引擎异常
  'packages/node_lua/lib/src/vendor/lua_runtime.dart', // 运行时错误
  'packages/node_lua/lib/src/lua_handlers.dart', // 命令/写动作错误
  'packages/node_lua/lib/src/lua_script_loader.dart', // 脚本校验错误 + 兜底名
  'packages/node_lua/lib/lua_plugin.dart', // scriptErrors 诊断
  'packages/node_data_recovery/lib/src/recovery_handlers.dart', // Verify 诊断输出
  // —— 模型元数据（Concept/Plugin 的 name/description——数据层语义，
  // 与种子标题同类；市场对话框显示的插件名即此元数据）——
  'packages/appframe/lib/src/ui/toolbar_concept.dart',
  'packages/appframe/lib/src/ui/toolbar_container_concept.dart',
  'packages/node_ai/lib/ai_plugin.dart',
  'packages/node_ai/lib/src/ai_concept.dart',
  'packages/node_ai/lib/src/ai_panel_concept.dart',
  'packages/node_ai/lib/src/ai_settings.dart',
  'packages/node_ai/lib/src/chat_concept.dart',
  'packages/node_ai/lib/src/ai_panel_commands.dart', // 面板实例默认标题（数据）
  'packages/node_converter/lib/converter_plugin.dart',
  'packages/node_data_recovery/lib/recovery_plugin.dart',
  'packages/node_editor/lib/editor_plugin.dart',
  'packages/node_editor/lib/src/editor_concept.dart',
  'packages/node_folder/lib/folder_plugin.dart',
  'packages/node_folder/lib/src/folder_concept.dart',
  'packages/node_folder/lib/src/contain_concept.dart',
  'packages/node_graph/lib/graph_plugin.dart',
  'packages/node_graph/lib/src/canvas_concept.dart',
  'packages/node_graph/lib/src/connection_concept.dart',
  'packages/node_i18n/lib/i18n_plugin.dart',
  'packages/node_i18n/lib/src/i18n_settings.dart',
  'packages/node_lua/lib/src/lua_concept.dart',
  'packages/node_market/lib/market_plugin.dart',
  'packages/appframe/lib/src/ui/recent_panel.dart', // C5 面板元数据+内部错误
  'packages/node_search/lib/search_plugin.dart',
  'packages/node_search/lib/src/search_panel.dart',
  'packages/node_search/lib/src/tags_panel.dart', // A2 面板元数据+内部错误
  'packages/node_settings/lib/settings_plugin.dart',
  'packages/node_settings/lib/src/settings_container.dart',
  'packages/node_settings/lib/src/theme_settings.dart',
  'packages/node_settings/lib/src/appearance_settings.dart',
  'packages/node_settings/lib/src/vault_settings.dart',
  // —— vendored 第三方包整体豁免（plugon 117 测试为上游资产）——
  'packages/plugon',
];

void main() {
  final root = Directory.current;
  final violations = <String>[];
  var filesScanned = 0;

  final packagesDir = Directory('${root.path}/packages');
  for (final pkg in packagesDir.listSync().whereType<Directory>()) {
    final pkgName = pkg.path.replaceAll('\\', '/').split('/').last;
    final relPkg = 'packages/$pkgName';
    if (_allowed(relPkg)) {
      continue;
    }
    final lib = Directory('${pkg.path}/lib');
    if (!lib.existsSync()) {
      continue;
    }
    for (final file in lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      filesScanned++;
      // 包内相对路径（含 lib/ 前缀）——与 allowlist 条目一致。
      final rel = 'packages/$pkgName/'
          '${file.path.substring(pkg.path.length + 1).replaceAll('\\', '/')}';
      if (_allowed(rel)) {
        continue;
      }
      for (final lineNo in _cjkInStrings(file.readAsStringSync())) {
        final line = file.readAsLinesSync().elementAt(lineNo - 1).trim();
        final snippet = line.length > 60 ? '${line.substring(0, 60)}…' : line;
        violations.add('$rel:$lineNo  $snippet');
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('check_hardcoded_strings: PASS（$filesScanned 文件扫描）');
    exitCode = 0;
  } else {
    stderr.writeln(
      'check_hardcoded_strings: ${violations.length} 处硬编码中文：',
    );
    violations.forEach(stderr.writeln);
    stderr.writeln('新 UI 文案必须进翻译表（05 纪律 7）；数据/协议层豁免'
        '需在 allowlist 注明理由。');
    exitCode = 1;
  }
}

bool _allowed(String rel) => allowlist.any((a) => rel == a || rel.startsWith('$a/'));

/// 状态机剥离注释后，返回字符串字面量内出现 CJK 的行号集合。
///
/// 状态：normal / string（单双引号）/ string3（''' 或 """）/ raw（r''）
/// / block / line / interp（`${}` 插值，防嵌套引号提前闭合漏检）。
/// 只对 string/string3 态累计 CJK 行；转义（`\uXXXX` 等）与插值
/// 内代码不计数——CJK 只可能以字面量形式出现在字符串正文。
List<int> _cjkInStrings(String src) {
  final hits = <int>{};
  var line = 1;
  var i = 0;
  var state = 'normal';
  var quote = 0;
  var depth = 0;

  while (i < src.length) {
    final c = src.codeUnitAt(i);
    final next = i + 1 < src.length ? src.codeUnitAt(i + 1) : -1;
    switch (state) {
      case 'normal':
        if (c == 0x2F && next == 0x2F) {
          state = 'line';
          i += 2;
        } else if (c == 0x2F && next == 0x2A) {
          state = 'block';
          i += 2;
        } else if (c == 0x72 && (next == 0x27 || next == 0x22)) {
          state = 'raw';
          quote = next;
          i += 2;
        } else if ((c == 0x27 || c == 0x22) &&
            next == c &&
            i + 2 < src.length &&
            src.codeUnitAt(i + 2) == c) {
          state = 'string3';
          quote = c;
          i += 3;
        } else if (c == 0x27 || c == 0x22) {
          state = 'string';
          quote = c;
          i++;
        } else {
          if (c == 0x0A) {
            line++;
          }
          i++;
        }
        break;
      case 'line':
        if (c == 0x0A) {
          state = 'normal';
          line++;
        }
        i++;
        break;
      case 'block':
        if (c == 0x0A) {
          line++;
        } else if (c == 0x2A && next == 0x2F) {
          state = 'normal';
          i += 2;
          continue;
        }
        i++;
        break;
      case 'raw':
        if (c == quote) {
          state = 'normal';
        } else if (c == 0x0A) {
          line++;
        }
        i++;
        break;
      case 'string':
        if (c == quote) {
          state = 'normal';
          i++;
        } else if (c == 0x5C) {
          i += 2;
        } else if (c == 0x24 && next == 0x7B) {
          state = 'interp';
          depth = 1;
          i += 2;
        } else {
          line = _count(c, line, hits);
          i++;
        }
        break;
      case 'string3':
        if (c == quote && next == quote) {
          state = 'normal';
          i += 2;
        } else if (c == 0x24 && next == 0x7B) {
          state = 'interp';
          depth = 1;
          i += 2;
        } else {
          line = _count(c, line, hits);
          i++;
        }
        break;
      case 'interp':
        // 插值内代码：嵌套字符串整体跳过（其内 CJK 计入该嵌套字符串
        // 自身——检查器的目标是外层层级，避免误标已豁免的 t() 调用）。
        if (c == 0x27 || c == 0x22) {
          i = _skipNestedString(src, i, c);
          continue;
        }
        if (c == 0x2F && next == 0x2F) {
          i = _skipLineComment(src, i);
          continue;
        }
        if (c == 0x2F && next == 0x2A) {
          final end = src.indexOf('*/', i + 2);
          if (end < 0) {
            return hits.toList()..sort();
          }
          line += '\n'.allMatches(src.substring(i, end)).length;
          i = end + 2;
          continue;
        }
        if (c == 0x7B) {
          depth++;
        } else if (c == 0x7D) {
          depth--;
          if (depth == 0) {
            state = 'string';
            i++;
            continue;
          }
        }
        if (c == 0x0A) {
          line++;
        }
        i++;
        break;
    }
  }
  return hits.toList()..sort();
}

/// 累计 CJK 命中并返回推进后的行号。
int _count(int c, int line, Set<int> hits) {
  if (c >= 0x4E00 && c <= 0x9FFF) {
    hits.add(line);
  }
  return c == 0x0A ? line + 1 : line;
}

/// 跳过嵌套字符串（从开引号到未转义闭引号），返回闭引号后一位。
int _skipNestedString(String src, int start, int quote) {
  var i = start + 1;
  while (i < src.length) {
    if (src.codeUnitAt(i) == 0x5C) {
      i += 2;
    } else if (src.codeUnitAt(i) == quote) {
      return i + 1;
    } else {
      i++;
    }
  }
  return src.length;
}

/// 跳过行注释，返回注释结束（\n）后一位。
int _skipLineComment(String src, int start) {
  final end = src.indexOf('\n', start + 2);
  return end < 0 ? src.length : end + 1;
}
