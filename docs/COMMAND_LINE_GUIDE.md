# Lua 脚本指南（M7 rewrite 架构）

> 2026-08-05 M7 重写：旧 registerHook API 全部作废（00 删除清单）。
> Lua 插件 = **动态 Concept 引擎**（01-E 承诺，docs/rewrite/04 §一）：
> 脚本定义 Concept（归属判定/呈现）与命令处理，宿主写 API 经命令总线。

## 脚本位置

- `data/lua_scripts/*.lua`（数据根下，可被编辑器/git 管理，00 §3.2）
- 应用运行时数据根 = 运行目录 `data/`
- Lua 运行时 = vendored Lua 5.4（`packages/node_lua/assets/lua54.dll`；
  应用分发须将 dll 放入应用目录或设 `NGN_LUA54_DLL` 环境变量）

## 脚本约定

每个脚本定义一个动态 Concept（`Concept` 全局表）：

```lua
Concept = {
  id = "com.example.mine:special",      -- 全局唯一（必填）
  name = "特殊节点",                     -- 展示名（必填）
  description = "Lua 动态 Concept",      -- 描述（可选）
  slots = { source = true },             -- references 键白名单（键集形态）
  requiredSlots = {},                    -- 匹配必填 references 键
  requiredMetadataKeys = { kind = true }, -- 匹配必填 metadata 键（键集形态）
  contentRequirement = "none",           -- "required" | "optional" | "none"
  validate = function(node)              -- 归属判定（可选；缺省 = Dart 侧
    return node.metadata.kind == "special"  -- 结构匹配兜底）
  end,
  createHook = function(node, kind)      -- 呈现面（可选；缺省占位 Hook）
    return { nodeId = node.id, hookId = node.id .. "@" .. kind }
  end,
}
```

**注意**：
- `slots` / `requiredMetadataKeys` 用**键集形态**（`{ kind = true }`）——
  数组形态的数字键不可枚举（M7 约定）。
- `node` 参数 = 宿主拼的 Lua 表（`id/title/content/references/metadata`，
  null 字段省略）。

## 命令处理（可选）

```lua
Commands = {
  ["mine.markSpecial"] = function(payload)
    local ok = host.node_update({ id = payload.target, metadata = { kind = "special" } })
    if string.sub(ok, 1, 8) == "affected" then
      return "affected:" .. payload.target .. ";data"
    end
    return ok
  end,
}
```

返回值约定字符串：
- `"affected:<id1>,<id2>;<kind>"` — 受影响节点 + 粒度（structure/data/ui）
- `"error:<消息>"` — 命令失败（用户可读文案）
- 其他 / 非字符串 — 空受影响 + data 粒度

## 宿主写 API

```lua
host.node_create({ id = "x", title = "…", content = "…",
                   references = {}, metadata = {} })   -- 创建节点
host.node_update({ id = "x", title = "…", metadata = { … } }) -- 更新
host.node_delete({ id = "x" })                          -- 删除节点
```

- 返回值：`"affected:<ids>;structure"` 或 `"error:<消息>"`
- **写操作唯一执行者仍是 Dart Handler**（00 不变量 4.4-1 的 Lua 侧落地）：
  Lua 的写请求经 C 回调 → `LuaWriteCommand` → `LuaWriteHandler` 落盘
  （含环校验——引用变更不因 Lua 而豁免）

## 安全沙箱

- 禁用：`os` / `io` / `package` / `require` / `debug` / `load*` /
  `collectgarbage` / `rawget` / `rawset`
- 脚本错误隔离：坏脚本跳过（不影响其他脚本与宿主）；引擎不可用
  （dll 缺失）→ 插件降级，宿主正常启动
- 已知限制：执行超时未实现（沙箱为 MVP 安全边界）[计划]：指令计数
  hook 方案已评估可行——lua_sethook + LUA_MASKCOUNT，lua54.dll 已编译
  hook 支持、ffi 绑定齐全（`lua_bindings.dart`），超时 = hook 内墙钟
  截止检查 → `luaL_error` 走既有 pcallk 错误路径（01 #54 裁决）

## 示例

`data/lua_scripts/special.lua`：

```lua
Concept = {
  id = "com.example.mine:special",
  name = "特殊节点",
  requiredMetadataKeys = { kind = true },
  validate = function(node)
    return node.metadata.kind == "special"
  end,
}
```
