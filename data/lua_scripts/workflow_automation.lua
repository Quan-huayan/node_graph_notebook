-- 实际应用场景：用户自定义工作流自动化
-- 这个脚本展示了一个真实的插件热插拔场景

print("🚀 工作流自动化插件启动")
print("=" .. string.rep("=", 50))

-- 定义自动化工作流
local Workflow = {}
Workflow.__index = Workflow

function Workflow.new(name)
    return setmetatable({
        name = name,
        steps = {},
        enabled = true
    }, Workflow)
end

function Workflow:addStep(step)
    table.insert(self.steps, step)
    return self
end

function Workflow:execute()
    if not self.enabled then
        print("⏸️  工作流已禁用: " .. self.name)
        return
    end

    print("▶️  执行工作流: " .. self.name)
    print("   步骤数: " .. #self.steps)

    for i, step in ipairs(self.steps) do
        print(string.format("   [%d/%d] %s", i, #self.steps, step))
    end

    print("✅ 工作流完成: " .. self.name)
    return true
end

-- 创建工作流实例
local morningRoutine = Workflow.new("晨间例行")
    :addStep("检查今日任务")
    :addStep("创建今日笔记")
    :addStep("整理优先级")
    :addStep("同步到云端")

-- 执行工作流
morningRoutine:execute()

print()
print("🎯 插件功能演示:")
print("  ✅ 创建自定义工作流")
print("  ✅ 运行时添加步骤")
print("  ✅ 条件执行逻辑")
print("  ✅ 完整的Lua语法支持")
print()
print("=" .. string.rep("=", 50))
print("插件加载完成！可以随时修改并重新加载。")
