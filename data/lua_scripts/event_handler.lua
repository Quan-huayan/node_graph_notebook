-- id: event-handler
-- name: Event Handler
-- description: 演示如何响应应用事件
-- author: Lua Plugin
-- version: 1.0.0
-- enabled: true
-- createdAt: 2026-03-21T00:00:00.000Z
-- updatedAt: 2026-03-21T00:00:00.000Z

-- 事件处理器示例
-- 演示如何监听和响应应用事件

debugPrint("=== 事件处理器已加载 ===")

-- 节点数据变更事件处理函数
function onNodeDataChanged(event)
    debugPrint("")
    debugPrint("=== 检测到节点数据变更 ===")

    if event.action then
        debugPrint("操作类型: " .. event.action)
    end

    if event.changedNodes then
        debugPrint("变更节点数量: " .. #event.changedNodes)

        for i, node in pairs(event.changedNodes) do
            debugPrint(string.format("  节点 %d: %s (ID: %s)", i, node.title, node.id))
        end
    end

    debugPrint("=== 事件处理完成 ===")
    debugPrint("")
end

-- 图数据变更事件处理函数
function onGraphDataChanged(event)
    debugPrint("")
    debugPrint("=== 检测到图数据变更 ===")

    if event.action then
        debugPrint("操作类型: " .. event.action)
    end

    if event.graphId then
        debugPrint("图ID: " .. event.graphId)
    end

    debugPrint("=== 事件处理完成 ===")
    debugPrint("")
end

-- 自定义事件处理函数示例
function handleNodeCreation(nodeId)
    debugPrint("检测到新节点创建: " .. nodeId)

    -- 可以在这里添加自定义逻辑
    -- 例如：自动添加标签、设置默认属性等
end

function handleNodeDeletion(nodeId)
    debugPrint("检测到节点删除: " .. nodeId)

    -- 可以在这里添加清理逻辑
    -- 例如：删除相关连接、清理缓存等
end

-- 脚本加载时的初始化
debugPrint("事件处理器注册完成")
debugPrint("监听事件:")
debugPrint("  - onNodeDataChanged")
debugPrint("  - onGraphDataChanged")
debugPrint("")
