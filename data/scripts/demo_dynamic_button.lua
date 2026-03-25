-- id: demo-dynamic-button
-- name: 动态工具栏按钮示例
-- description: 演示如何动态创建和删除工具栏按钮
-- author: Lua Plugin System
-- version: 1.0.0
-- enabled: true
-- createdAt: 2026-03-23T00:00:00.000Z
-- updatedAt: 2026-03-23T00:00:00.000Z

debugPrint("========================================")
debugPrint("动态工具栏按钮示例脚本")
debugPrint("========================================")

-- 定义回调函数
onButtonClick = function()
    debugPrint("按钮被点击了！")
    showMessage("动态按钮被点击！")

    -- 获取所有节点
    getAllNodes("onGetAllNodes")
end

-- 获取节点后的回调
onGetAllNodes = function(success, result)
    if success then
        debugPrint("当前有 " .. result.count .. " 个节点")
    else
        debugPrint("获取节点失败: " .. (result.error or "未知错误"))
    end
end

-- 注册工具栏按钮
debugPrint("正在注册工具栏按钮...")
local result = registerToolbarButton(
    "demo_button",           -- 按钮ID
    "点击我",                 -- 按钮标签
    "onButtonClick",         -- 点击回调函数名
    "play_arrow"             -- 图标名称
)

if result == 1 then
    debugPrint("✓ 工具栏按钮注册成功！")
    debugPrint("  - 按钮ID: demo_button")
    debugPrint("  - 标签: 点击我")
    debugPrint("  - 回调: onButtonClick")
    debugPrint("  - 图标: play_arrow")
else
    debugPrint("✗ 工具栏按钮注册失败")
end

debugPrint("========================================")
debugPrint("提示：使用 unregisterToolbarButton('demo_button') 可以卸载此按钮")
debugPrint("========================================")
