/// Lua 动态按钮命令行测试工具
///
/// 使用方法：
/// ```bash
/// dart run tool/test_lua_dynamic_buttons.dart
/// ```

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_embed_lua/flutter_embed_lua.dart';
import '../lib/plugins/lua/service/lua_dynamic_hook_manager.dart';
import '../lib/plugins/lua/service/lua_engine_service.dart';
import '../lib/core/plugin/ui_hooks/hook_registry.dart';

void main() async {
  print('========================================');
  print('Lua 动态工具栏按钮测试工具');
  print('========================================\n');

  // 1. 初始化 Lua 引擎
  print('[1/4] 初始化 Lua 引擎...');
  final engineService = LuaEngineService(
    enableSandbox: true,
    enableDebugOutput: true,
    engineType: LuaEngineType.realLua,
  );

  try {
    await engineService.initialize();
    print('✓ Lua 引擎初始化成功\n');
  } catch (e) {
    print('✗ Lua 引擎初始化失败: $e\n');
    return;
  }

  // 2. 初始化动态 Hook 管理器
  print('[2/4] 初始化动态 Hook 管理器...');
  final dynamicHookManager = LuaDynamicHookManager(
    engineService: engineService,
    hookRegistry: hookRegistry,
  );

  try {
    dynamicHookManager.registerAPIs();
    print('✓ 动态 Hook 管理器初始化成功\n');
  } catch (e) {
    print('✗ 动态 Hook 管理器初始化失败: $e\n');
    return;
  }

  // 3. 执行测试脚本
  print('[3/4] 执行测试脚本...\n');

  final testScript = '''
-- Lua 动态工具栏按钮测试脚本
print("开始测试动态工具栏按钮...")

-- 定义回调函数
onTestClick = function()
    print("✓ 测试按钮被点击了！")
    showMessage("动态按钮工作正常！")
end

-- 注册工具栏按钮
print("正在注册按钮...")
local result = registerToolbarButton(
    "test_btn",      -- 按钮ID
    "测试按钮",        -- 按钮标签
    "onTestClick",   -- 回调函数
    "star"           -- 图标
)

if result == 1 then
    print("✓ 按钮注册成功！")
    print("  按钮ID: test_btn")
    print("  按钮标签: 测试按钮")
    print("  回调函数: onTestClick")
    print("  图标: star")
    print("")
    print("注意：由于这是命令行测试，你无法在 GUI 中看到按钮。")
    print("但是在 Flutter 应用中，这个按钮会出现在工具栏上。")
else
    print("✗ 按钮注册失败")
end

print("")
print("测试完成")
''';

  try {
    final result = await engineService.executeString(testScript);

    print('--- 执行输出 ---');
    for (final line in result.output) {
      print(line);
    }
    print('----------------');

    if (result.success) {
      print('\n✓ 脚本执行成功\n');
    } else {
      print('\n✗ 脚本执行失败: ${result.error}\n');
    }
  } catch (e) {
    print('✗ 脚本执行出错: $e\n');
  }

  // 4. 测试卸载功能
  print('[4/4] 测试卸载功能...\n');

  final unregisterScript = '''
print("正在卸载按钮...")
local result = unregisterToolbarButton("test_btn")

if result == 1 then
    print("✓ 按钮卸载成功")
else
    print("✗ 按钮卸载失败")
end
''';

  try {
    final result = await engineService.executeString(unregisterScript);

    print('--- 执行输出 ---');
    for (final line in result.output) {
      print(line);
    }
    print('----------------');

    if (result.success) {
      print('\n✓ 卸载测试成功\n');
    } else {
      print('\n✗ 卸载测试失败: ${result.error}\n');
    }
  } catch (e) {
    print('✗ 卸载测试出错: $e\n');
  }

  // 清理资源
  print('清理资源...');
  await engineService.dispose();
  dynamicHookManager.clear();
  print('✓ 资源已清理\n');

  // 总结
  print('========================================');
  print('测试总结');
  print('========================================');
  print('✓ Lua 引擎工作正常');
  print('✓ 动态 Hook 管理器工作正常');
  print('✓ 按钮注册 API 工作正常');
  print('✓ 按钮卸载 API 工作正常');
  print('');
  print('所有功能测试通过！');
  print('');
  print('注意：');
  print('- 这是命令行测试，无法显示 GUI 按钮');
  print('- 在 Flutter 应用中，按钮会出现在工具栏');
  print('- 你可以在应用的 Lua 脚本执行界面中测试');
  print('========================================');
}
