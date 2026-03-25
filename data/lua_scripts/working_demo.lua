-- Lua API 工作演示脚本
-- 功能：演示Lua脚本如何调用笔记本软件API

debugPrint("==================================================")
debugPrint("Lua API 演示脚本")
debugPrint("==================================================")
debugPrint()

-- 1. 基础打印
debugPrint("✅ 步骤1: 基础打印功能")
debugPrint("  欢迎使用Node Graph Notebook!")
debugPrint()

-- 2. 变量操作
debugPrint("✅ 步骤2: 变量操作")
local appName = "Node Graph Notebook"
local version = "1.0.0"
debugPrint("  应用: " .. appName)
debugPrint("  版本: " .. version)
debugPrint()

-- 3. 条件判断
debugPrint("✅ 步骤3: 条件判断")
local isTestMode = true
if isTestMode then
  debugPrint("  模式: 测试模式")
end
debugPrint()

-- 4. 循环操作
debugPrint("✅ 步骤4: 循环创建节点")
for i = 1, 3 do
  local nodeName = "节点_" .. i
  debugPrint("  创建: " .. nodeName)
end
debugPrint()

-- 5. 函数调用（使用副作用而非返回值）
debugPrint("✅ 步骤5: 自定义函数")
_result = ""
function formatNode(title, tag)
  _result = title
  if tag ~= nil then
    _result = title .. " [" .. tag .. "]"
  end
  debugPrint("  " .. _result)
end

formatNode("重要概念", "学习")
formatNode("笔记", nil)
debugPrint()

-- 6. API调用演示
debugPrint("✅ 步骤6: API调用演示")
debugPrint("  以下API需要在Dart中注册:")
debugPrint("  - createNode(name)")
debugPrint("  - showMessage(msg)")
debugPrint("  - getNodeCount()")
debugPrint()

debugPrint("==================================================")
debugPrint("✅ 脚本执行完成!")
debugPrint("==================================================")
