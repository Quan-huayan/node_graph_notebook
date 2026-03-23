-- id: unregister-buttons
-- name: 卸载工具栏按钮
-- description: 演示如何卸载动态工具栏按钮
-- author: Lua Plugin System
-- version: 1.0.0
-- enabled: true
-- createdAt: 2026-03-23T00:00:00.000Z
-- updatedAt: 2026-03-23T00:00:00.000Z

print("========================================")
print("卸载工具栏按钮示例")
print("========================================")

-- 首先列出当前所有按钮
print("当前已注册的动态按钮:")
local buttons = listDynamicButtons()

if #buttons == 0 then
    print("  (没有动态按钮)")
else
    for i, btn in pairs(buttons) do
        print("  " .. i .. ". " .. btn.label .. " (ID: " .. btn.id .. ")")
    end
end

print("")

-- 卸载指定按钮
local buttonToUnregister = "demo_button"

print("正在卸载按钮: " .. buttonToUnregister)
local result = unregisterToolbarButton(buttonToUnregister)

if result == 1 then
    print("✓ 按钮卸载成功！")
else
    print("✗ 按钮卸载失败 (可能不存在)")
end

print("")

-- 再次列出按钮
print("卸载后的动态按钮:")
local buttonsAfter = listDynamicButtons()

if #buttonsAfter == 0 then
    print("  (没有动态按钮)")
else
    for i, btn in pairs(buttonsAfter) do
        print("  " .. i .. ". " .. btn.label .. " (ID: " .. btn.id .. ")")
    end
end

print("========================================")
print("提示：重新运行 'demo_dynamic_button' 脚本可以重新注册按钮")
print("========================================")
