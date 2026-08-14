-- Lua API 工作演示脚本
-- 功能：演示Lua脚本如何调用笔记本软件API

print("==================================================")
print("Lua API 演示脚本")
print("==================================================")
print()

-- 1. 基础打印
print("✅ 步骤1: 基础打印功能")
print("  欢迎使用Node Graph Notebook!")
print()

-- 2. 变量操作
print("✅ 步骤2: 变量操作")
local appName = "Node Graph Notebook"
local version = "1.0.0"
print("  应用: " .. appName)
print("  版本: " .. version)
print()

-- 3. 条件判断
print("✅ 步骤3: 条件判断")
local isTestMode = true
if isTestMode then
  print("  模式: 测试模式")
end
print()

-- 4. 循环操作
print("✅ 步骤4: 循环创建节点")
for i = 1, 3 do
  local nodeName = "节点_" .. i
  print("  创建: " .. nodeName)
end
print()

-- 5. 函数调用（使用副作用而非返回值）
print("✅ 步骤5: 自定义函数")
_result = ""
function formatNode(title, tag)
  _result = title
  if tag ~= nil then
    _result = title .. " [" .. tag .. "]"
  end
  print("  " .. _result)
end

formatNode("重要概念", "学习")
formatNode("笔记", nil)
print()

-- 6. API调用演示
print("✅ 步骤6: API调用演示")
print("  以下API需要在Dart中注册:")
print("  - createNode(name)")
print("  - showMessage(msg)")
print("  - getNodeCount()")
print()

print("==================================================")
print("✅ 脚本执行完成!")
print("==================================================")
