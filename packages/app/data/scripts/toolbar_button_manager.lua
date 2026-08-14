-- id: toolbar-button-manager
-- name: 工具栏按钮管理器
-- description: 提供多个工具栏按钮的管理功能
-- author: Lua Plugin System
-- version: 1.0.0
-- enabled: true
-- createdAt: 2026-03-23T00:00:00.000Z
-- updatedAt: 2026-03-23T00:00:00.000Z

print("========================================")
print("工具栏按钮管理器")
print("========================================")

-- 创建节点按钮回调
onCreateNodeClick = function()
    print("创建节点按钮被点击")
    createNode("从Lua创建的节点", "这是通过动态工具栏按钮创建的节点", nil)
    showMessage("节点已创建！")
end

-- 列出节点按钮回调
onListNodesClick = function()
    print("列出节点按钮被点击")
    getAllNodes("onListNodesComplete")
end

onListNodesComplete = function(success, result)
    if success then
        print("找到 " .. result.count .. " 个节点")
        showMessage("共有 " .. result.count .. " 个节点")
    end
end

-- 显示时间按钮回调
onShowTimeClick = function()
    local time = getCurrentTime()
    print("当前时间: " .. time)
    showMessage("当前时间: " .. time)
end

-- 注册多个按钮
print("正在注册工具栏按钮...")

-- 按钮1: 创建节点
registerToolbarButton("create_node_btn", "创建节点", "onCreateNodeClick", "add")

-- 按钮2: 列出节点
registerToolbarButton("list_nodes_btn", "列出节点", "onListNodesClick", "list")

-- 按钮3: 显示时间
registerToolbarButton("show_time_btn", "显示时间", "onShowTimeClick", "access_time")

print("✓ 所有按钮注册成功！")
print("")

-- 列出所有动态按钮
print("已注册的动态按钮:")
local buttons = listDynamicButtons()
for i, btn in pairs(buttons) do
    print("  " .. (i+1) .. ". " .. btn.label .. " (ID: " .. btn.id .. ")")
end

print("========================================")
print("提示：")
print("  - 使用 unregisterToolbarButton('create_node_btn') 删除按钮")
print("  - 使用 listDynamicButtons() 查看所有按钮")
print("========================================")
