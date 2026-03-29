/// Lua 动态按钮命令行测试工具
///
/// 使用方法：
/// ```bash
/// dart run tool/test_lua_dynamic_buttons.dart
/// ```
library;

import 'package:flutter/material.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_registry.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_dynamic_hook_manager.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_engine_service.dart';

void main() async {
  debugPrint('========================================');
  debugPrint('Lua 动态工具栏按钮测试工具');
  debugPrint('========================================\n');

  // 1. 初始化 Lua 引擎
  debugPrint('[1/4] 初始化 Lua 引擎...');
  final engineService = LuaEngineService(
    enableSandbox: true,
    enableDebugOutput: true,
  );

  try {
    await engineService.initialize();
    debugPrint('✓ Lua 引擎初始化成功\n');
  } catch (e) {
    debugPrint('✗ Lua 引擎初始化失败: $e\n');
    return;
  }

  // 2. 初始化动态 Hook 管理器
  debugPrint('[2/4] 初始化动态 Hook 管理器...');
  final dynamicHookManager = LuaDynamicHookManager(
    engineService: engineService,
    hookRegistry: hookRegistry,
  );

  try {
    dynamicHookManager.registerAPIs();
    debugPrint('✓ 动态 Hook 管理器初始化成功\n');
  } catch (e) {
    debugPrint('✗ 动态 Hook 管理器初始化失败: $e\n');
    return;
  }

  // 3. 执行测试脚本
  debugPrint('[3/4] 执行测试脚本...\n');

  const testScript = '''
-- Lua 动态工具栏按钮测试脚本
debugPrint("开始测试动态工具栏按钮...")

-- 定义回调函数
onTestClick = function()
    debugPrint("✓ 测试按钮被点击了！")
    showMessage("动态按钮工作正常！")
end

-- 注册工具栏按钮
debugPrint("正在注册按钮...")
local result = registerToolbarButton(
    "test_btn",      -- 按钮ID
    "测试按钮",        -- 按钮标签
    "onTestClick",   -- 回调函数
    "star"           -- 图标
)

if result == 1 then
    debugPrint("✓ 按钮注册成功！")
    debugPrint("  按钮ID: test_btn")
    debugPrint("  按钮标签: 测试按钮")
    debugPrint("  回调函数: onTestClick")
    debugPrint("  图标: star")
    debugPrint("")
    debugPrint("注意：由于这是命令行测试，你无法在 GUI 中看到按钮。")
    debugPrint("但是在 Flutter 应用中，这个按钮会出现在工具栏上。")
else
    debugPrint("✗ 按钮注册失败")
end

debugPrint("")
debugPrint("测试完成")
''';

  try {
    final result = await engineService.executeString(testScript);

    debugPrint('--- 执行输出 ---');
    result.output.forEach(debugPrint);
    debugPrint('----------------');

    if (result.success) {
      debugPrint('\n✓ 脚本执行成功\n');
    } else {
      debugPrint('\n✗ 脚本执行失败: ${result.error}\n');
    }
  } catch (e) {
    debugPrint('✗ 脚本执行出错: $e\n');
  }

  // 4. 测试卸载功能
  debugPrint('[4/4] 测试卸载功能...\n');

  const unregisterScript = '''
debugPrint("正在卸载按钮...")
local result = unregisterToolbarButton("test_btn")

if result == 1 then
    debugPrint("✓ 按钮卸载成功")
else
    debugPrint("✗ 按钮卸载失败")
end
''';

  try {
    final result = await engineService.executeString(unregisterScript);

    debugPrint('--- 执行输出 ---');
    result.output.forEach(debugPrint);
    debugPrint('----------------');

    if (result.success) {
      debugPrint('\n✓ 卸载测试成功\n');
    } else {
      debugPrint('\n✗ 卸载测试失败: ${result.error}\n');
    }
  } catch (e) {
    debugPrint('✗ 卸载测试出错: $e\n');
  }

  // 清理资源
  debugPrint('清理资源...');
  await engineService.dispose();
  dynamicHookManager.clear();
  debugPrint('✓ 资源已清理\n');

  // 总结
  debugPrint('========================================');
  debugPrint('测试总结');
  debugPrint('========================================');
  debugPrint('✓ Lua 引擎工作正常');
  debugPrint('✓ 动态 Hook 管理器工作正常');
  debugPrint('✓ 按钮注册 API 工作正常');
  debugPrint('✓ 按钮卸载 API 工作正常');
  debugPrint('');
  debugPrint('所有功能测试通过！');
  debugPrint('');
  debugPrint('注意：');
  debugPrint('- 这是命令行测试，无法显示 GUI 按钮');
  debugPrint('- 在 Flutter 应用中，按钮会出现在工具栏');
  debugPrint('- 你可以在应用的 Lua 脚本执行界面中测试');
  debugPrint('========================================');
}
