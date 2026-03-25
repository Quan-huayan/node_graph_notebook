-- id: node-organizer
-- name: Node Organizer
-- description: 自动整理节点的脚本，演示API调用
-- author: Lua Plugin
-- version: 1.0.0
-- enabled: true
-- createdAt: 2026-03-21T00:00:00.000Z
-- updatedAt: 2026-03-21T00:00:00.000Z

-- 节点整理器示例
-- 演示如何使用Lua API操作节点

print("=== 节点整理器启动 ===")

-- 获取所有节点
local nodes = getAllNodes()
print("找到 " .. #nodes .. " 个节点")

-- 统计节点信息
local totalNodes = 0
local nodesWithContent = 0

for i, node in pairs(nodes) do
    totalNodes = totalNodes + 1

    if node.content ~= nil and node.content ~= "" then
        nodesWithContent = nodesWithContent + 1
    end

    print(string.format("节点 %d: %s", i, node.title))
end

-- 输出统计信息
print("")
print("=== 统计信息 ===")
print("总节点数: " .. totalNodes)
print("有内容的节点: " .. nodesWithContent)
print("空节点: " .. (totalNodes - nodesWithContent))

-- 演示创建新节点（如果API可用）
if createNode then
    print("")
    print("创建整理报告节点...")

    local reportContent = string.format([[
# 节点整理报告

生成时间: %s

## 统计信息
- 总节点数: %d
- 有内容的节点: %d
- 空节点: %d

## 详细列表
]], os.date("%Y-%m-%d %H:%M:%S"), totalNodes, nodesWithContent, (totalNodes - nodesWithContent))

    for i, node in pairs(nodes) do
        reportContent = reportContent .. string.format("- %s\n", node.title)
    end

    -- 注意：实际创建节点需要完整的API实现
    print("报告内容已生成")
    print(reportContent)
end

print("")
print("=== 节点整理完成 ===")
