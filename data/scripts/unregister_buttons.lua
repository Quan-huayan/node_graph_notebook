-- id: unregister-buttons
-- name: 卸载工具栏按钮
-- description: 演示如何卸载动态工具栏按钮
-- author: Lua Plugin System
-- version: 1.0.0
-- enabled: true
-- createdAt: 2026-03-23T00:00:00.000Z
-- updatedAt: 2026-03-23T00:00:00.000Z

debugPrint("========================================")
debugPrint("卸载工具栏按钮示例")
debugPrint("========================================")

-- 首先列出当前所有按钮
debugPrint("当前已注册的动态按钮:")
local buttons = listDynamicButtons()

if #buttons == 0 then
    debugPrint("  (没有动态按钮)")
else
    for i, btn in pairs(buttons) do
        debugPrint("  " .. i .. ". " .. btn.label .. " (ID: " .. btn.id .. ")")
    end
end

debugPrint("")

-- 卸载指定按钮
local buttonToUnregister = "demo_button"

debugPrint("正在卸载按钮: " .. buttonToUnregister)
local result = unregisterToolbarButton(buttonToUnregister)

if result == 1 then
    debugPrint("✓ 按钮卸载成功！")
else
    debugPrint("✗ 按钮卸载失败 (可能不存在)")
end

debugPrint("")

-- 再次列出按钮
debugPrint("卸载后的动态按钮:")
local buttonsAfter = listDynamicButtons()

if #buttonsAfter == 0 then
    debugPrint("  (没有动态按钮)")
else
    for i, btn in pairs(buttonsAfter) do
        debugPrint("  " .. i .. ". " .. btn.label .. " (ID: " .. btn.id .. ")")
    end
end

debugPrint("========================================")
debugPrint("提示：重新运行 'demo_dynamic_button' 脚本可以重新注册按钮")
debugPrint("========================================")
