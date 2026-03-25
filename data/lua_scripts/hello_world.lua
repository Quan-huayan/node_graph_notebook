-- id: hello-world
-- name: Hello World
-- description: 简单的Hello World示例，演示Lua脚本的基本使用
-- author: Lua Plugin
-- version: 1.0.0
-- enabled: true
-- createdAt: 2026-03-21T00:00:00.000Z
-- updatedAt: 2026-03-21T00:00:00.000Z

-- Hello World 示例脚本
-- 这是你的第一个Lua脚本

debugPrint("Hello from Lua!")
debugPrint("欢迎使用Node Graph Notebook Lua脚本系统")

-- 演示变量使用
local message = "这是一个Lua变量"
debugPrint(message)

-- 演示函数定义
local function greet(name)
    debugPrint("你好, " .. name .. "!")
end

greet("用户")

-- 演示循环
debugPrint("计数器:")
for i = 1, 5 do
    debugPrint("  第 " .. i .. " 次循环")
end

-- 演示条件语句
local counter = 10
if counter > 5 then
    debugPrint("counter大于5")
else
    debugPrint("counter小于或等于5")
end

debugPrint("脚本执行完成！")
