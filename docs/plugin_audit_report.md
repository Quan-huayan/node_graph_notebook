# Plugin System Audit Report

> 审查日期：2026-06-29
>
> 审查范围：`packages/` 下全部 15 个 Plugin 实现
>
> 依据规范：[Plugin System Specification](./plugin_system_specification.md)

---

## 执行摘要

审查了 15 个插件（不含 MiddlewarePlugin 抽象类）。发现 **3 个 HIGH 级问题**（插件 ID 命名不规范）、**10 个 MEDIUM 级问题**（依赖声明缺失）、**8 个 LOW 级问题**（冗余代码/反模式）。

**合规度评分：**

| 评级 | 插件数 | 插件 |
|------|--------|------|
| ✅ 合规 | 3 | CorePlugin, AppFramePlugin, SearchPlugin |
| ⚠️ 基本合规 | 3 | GraphPlugin, DataRecoveryPlugin, i18nZhPlugin |
| 🔶 需改进 | 9 | FolderPlugin, EditorPlugin, ConverterPlugin, LayoutPlugin, SettingsPlugin, MarketPlugin, AIPlugin, LuaPlugin, i18nEnPlugin |

---

## 1. 逐插件审查

### 1.1 CorePlugin — ✅ 合规

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `core` | |
| 依赖声明 | ✅ 无（核心插件） | |
| Service 注册 | ✅ 8 个服务 | 正确使用 `singleton` / `notifier` / `notifierFactory` |
| Hook 注册 | ✅ 空（正确） | 核心插件不注册业务 Hook |
| Bloc 注册 | ✅ 空（正确） | 核心插件不注册 Bloc |
| onLoad | ✅ 空（正确） | 初始化逻辑在构造函数 |
| owner 标注 | ✅ 全部 `metadata.id` | |

**评价：** 参考实现。服务注册规范，使用正确的 ServiceRegistration 类型。

---

### 1.2 AppFramePlugin — ✅ 合规

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `appframe` | |
| 依赖声明 | ✅ `['core']` | |
| Service 注册 | ✅ 3 个服务 | ThemeRegistry, ThemeService, StoragePathService |
| Hook 注册 | ✅ 空（有原因） | 布局 Hook 由 AppFrameInitializer 注册 |
| Bloc 注册 | ✅ 空 | |

**评价：** 实现正确。注释已更新说明 Hook 注册方式。

---

### 1.3 GraphPlugin — ⚠️ 基本合规

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `graph` | |
| 依赖声明 | ✅ `['core', 'appframe']` | |
| Service 注册 | ✅ 2 个服务 | NodeService, GraphService |
| Hook 注册 | ✅ 3 个 Hook | GraphNodesToolbarHook, RefreshGraphToolbarHook, ToggleConnectionsToolbarHook |
| Bloc 注册 | ✅ 2 个 Bloc | NodeBloc, GraphBloc |
| onLoad | ✅ 注册 17 个 Handler + 3 个 TaskType | |

**评价：** 良好。`_registerCommandHandlers` 方法可考虑拆分。

---

### 1.4 SearchPlugin — ✅ 合规

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `search` | |
| 依赖声明 | ✅ `['graph']` | |
| Service 注册 | ✅ 1 个服务 | SearchPresetService |
| Hook 注册 | ✅ 1 个 Hook | SearchSidebarHook |
| Bloc 注册 | ✅ 1 个 Bloc | SearchBloc |
| onLoad | ✅ 注册 2 个 Handler | |

**评价：** 完全合规，可作为中小型插件的参考模板。

---

### 1.5 FolderPlugin — 🔶 需改进

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | 🔴 **`folder_plugin`** | 应改为 `folder`（去掉 `_plugin` 后缀） |
| 依赖声明 | ✅ `['graph']` | |
| Service 注册 | 🟡 空列表（冗余） | `[]` 是默认值，可省略 |
| Hook 注册 | ✅ 1 个 Hook | FolderSidebarTabHook |
| 死代码 | 🟡 `nodeTemplates` | 旧系统的 NodeTemplateRegistry，已无用 |

**需要修改：**
1. **HIGH** — 插件 ID 从 `folder_plugin` 改为 `folder`
2. **LOW** — 删除 `registerServices() => []`
3. **LOW** — 删除 `nodeTemplates` getter（旧系统残留）

---

### 1.6 EditorPlugin — 🔶 需改进

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | 🔴 **`editor_plugin`** | 应改为 `editor` |
| 依赖声明 | 🔴 **缺失** | 使用了 `NodeBloc`（来自 graph）、`UILayoutService`（来自 core），但未声明依赖 |
| Service 注册 | 🟡 空列表（冗余） | |
| Hook 注册 | ✅ 1 个 Hook + 自定义 Hook 点 | |
| Hook 实现 | 🟡 参数类型放宽 | `buildContent(HookContext)` 而非 `buildContent(SidebarHookContext)` |
| 死代码 | 🟡 `node_editor_panel_hook.dart` | 完整版 Editor Hook 未使用 |

**需要修改：**
1. **HIGH** — 插件 ID 从 `editor_plugin` 改为 `editor`
2. **MEDIUM** — 添加 `dependencies: ['core', 'appframe', 'graph']`
3. **LOW** — 删除 `registerServices() => []` / `registerBlocs() => []`
4. **LOW** — 删除未使用的 `node_editor_panel_hook.dart`（或标记为备用实现）
5. **LOW** — 将 `buildContent(HookContext)` 改为 `buildContent(SidebarHookContext)`

---

### 1.7 ConverterPlugin — 🔶 需改进

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `converter` | |
| 依赖声明 | 🔴 **缺失** | 使用了 `CommandBus`、`ImportExportService`，但未声明依赖 |
| Service 注册 | 🟡 空列表（冗余） | |
| Hook 注册 | ✅ 1 个 Hook | ConverterToolbarHook |
| Bloc 注册 | ✅ 1 个 Bloc | ConverterBloc |
| onLoad | ✅ 注册 5 个 Handler | |

**需要修改：**
1. **MEDIUM** — 添加 `dependencies: ['core', 'appframe']`
2. **LOW** — 删除 `registerServices() => []`

---

### 1.8 LayoutPlugin — 🔶 需改进

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `layout` | |
| 依赖声明 | 🔴 **缺失** | 使用了 `GraphService`(graph)、`UILayoutService`(core)、`NodeRepository`(core) |
| Service 注册 | 🟡 空列表（冗余） | |
| Hook 注册 | ✅ 1 个 Hook | LayoutToolbarHook |
| onLoad | ✅ 注册 2 个 Handler | |

**需要修改：**
1. **MEDIUM** — 添加 `dependencies: ['core', 'graph']`
2. **LOW** — 删除 `registerServices() => []`

---

### 1.9 SettingsPlugin — 🔶 需改进

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `settings` | |
| 依赖声明 | 🔴 **缺失** | 使用了 `hookRegistry`、`I18n`（通过 Provider） |
| Service 注册 | 🟡 空列表（冗余） | |
| Hook 注册 | ✅ 1 个 Hook | SettingsToolbarHook |
| enabledByDefault | 🟡 未显式设置 | 默认 `true`，推荐显式声明 |

**需要修改：**
1. **MEDIUM** — 添加 `dependencies: ['core', 'appframe']`
2. **LOW** — 删除 `registerServices() => []`
3. **LOW** — 显式设置 `enabledByDefault: true`

---

### 1.10 MarketPlugin — 🔶 需改进

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `market` | |
| 依赖声明 | 🔴 **缺失** | 使用了 `hookRegistry`、`I18n` |
| Service 注册 | 🟡 空列表（冗余） | |
| Hook 注册 | ✅ 1 个 Hook | MarketToolbarHook |

**需要修改：**
1. **MEDIUM** — 添加 `dependencies: ['core', 'appframe']`
2. **LOW** — 删除 `registerServices() => []`

---

### 1.11 AIPlugin — 🔶 需改进

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | 🔴 **`ai_plugin`** | 应改为 `ai` |
| 依赖声明 | 🔴 **缺失** | 使用了 `NodeService`(graph)、`SettingsRegistry`(core)、`SharedPreferencesAsync` |
| Service 注册 | 🟡 空列表（冗余） | |
| Hook 注册 | ✅ 3 个 Hook | AIIntegrationHook, AISettingsHook, AIToolbarHook |
| onLoad 实现 | 🟡 使用 `SharedPreferencesAsync` 直接 | 应通过 `SettingsRegistry` |
| Hook 功能 | 🟡 4 个菜单项均显示 "not implemented" | 功能未完成 |

**需要修改：**
1. **HIGH** — 插件 ID 从 `ai_plugin` 改为 `ai`
2. **MEDIUM** — 添加 `dependencies: ['core', 'graph']`
3. **LOW** — 删除 `registerServices() => []`
4. **LOW** — `_migrateLegacySettings` 应使用 `SettingsRegistry` 而非 `SharedPreferencesAsync` 直接

---

### 1.12 LuaPlugin — 🔶 需改进

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `lua` | |
| 依赖声明 | 🔴 **缺失** | 使用了 `NodeRepository`、`GraphRepository`、`CommandBus`、`LuaScriptService` |
| Service 注册 | 🟡 空列表（冗余） | |
| Hook 注册 | 🟡 空（使用动态 Hook） | 通过 `LuaDynamicHookManager` 管理 |
| 全局单例 | 🔴 使用全局 `hookRegistry` | 应通过 DI 获取 |
| onLoad | 🟡 方法过长 | 初始化引擎 + API + 动态 Hook + Handler 混在一起 |
| 服务引用 | 🟡 存储为字段 | `_engineService`、`_scriptService` 等存为实例字段 |

**需要修改：**
1. **MEDIUM** — 添加 `dependencies: ['core', 'appframe']`
2. **MEDIUM** — `hookRegistry` 应从 `context.tryGet<HookRoleRegistry>()` 获取，而非全局单例
3. **LOW** — 删除 `registerServices() => []`
4. **LOW** — 拆分 `onLoad` 为多个私有方法
5. **LOW** — 服务引用考虑通过 `ServiceRegistry` 获取，减少字段存储

---

### 1.13 i18nEnPlugin — 🔶 需改进

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `i18n_en` | |
| 依赖声明 | 🔴 **缺失** | 使用了 `I18n`（来自 core） |
| Service 注册 | 🟡 空列表（冗余） | |
| enabledByDefault | 🟡 未显式设置 | |

**需要修改：**
1. **MEDIUM** — 添加 `dependencies: ['core']`
2. **LOW** — 删除 `registerServices() => []`
3. **LOW** — 显式设置 `enabledByDefault: true`

---

### 1.14 i18nZhPlugin — ⚠️ 基本合规

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `i18n_zh` | |
| 依赖声明 | 🔴 **缺失** | 使用了 `I18n`（来自 core） |
| Service 注册 | 🟡 空列表（冗余） | |
| enabledByDefault | 🟡 未显式设置 | |

**需要修改：** 同 i18nEnPlugin。

---

### 1.15 DataRecoveryPlugin — ⚠️ 基本合规

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 插件 ID | ✅ `data_recovery` | |
| 依赖声明 | 🔴 **缺失** | 使用了 `NodeRepository`、`GraphRepository`、`StoragePathService`、`CommandBus` |
| Service 注册 | 🟡 空列表（冗余） | |
| Hook 注册 | ✅ 空（正确） | 纯后端插件 |
| onLoad | ✅ 注册 3 个 Handler | |

**需要修改：**
1. **MEDIUM** — 添加 `dependencies: ['core', 'appframe']`
2. **LOW** — 删除 `registerServices() => []`

---

## 2. 问题汇总

### 2.1 按严重度

| 严重度 | 数量 | 问题 |
|--------|------|------|
| 🔴 HIGH | 3 | 插件 ID 命名不规范 (folder_plugin→folder, editor_plugin→editor, ai_plugin→ai) |
| 🟠 MEDIUM | 10 | 依赖声明缺失（10 个插件） |
| 🟡 LOW | 8 | `registerServices() => []` 冗余代码 |
| 🟡 LOW | 2 | 全局单例反模式 (LuaPlugin, AIPlugin) |
| 🟡 LOW | 1 | 死代码 (EditorPlugin 旧版 Hook) |
| 🟡 LOW | 1 | Hook 参数类型放宽 (EditorPlugin) |
| 🟡 LOW | 3 | enabledByDefault 未显式设置 |
| 🟡 LOW | 1 | LuaPlugin onLoad 方法过长 |

### 2.2 按分类

| 分类 | 插件数 | 问题 |
|------|--------|------|
| ID 命名 | 3 | folder_plugin, editor_plugin, ai_plugin |
| 依赖声明 | 10 | Editor, Converter, Layout, Settings, Market, AI, Lua, i18nEn, i18nZh, DataRecovery |
| 冗余代码 | 8 | Folder, Editor, Converter, Layout, Settings, Market, AI, Lua |
| 反模式 | 2 | Lua (全局单例), AI (直接 SharedPreferencesAsync) |
| 死代码 | 1 | Editor (node_editor_panel_hook.dart) |

---

## 3. 修改优先级建议

### 第一批 — 立即修复

| 优先级 | 修改 | 影响 |
|--------|------|------|
| P0 | 补全 10 个插件的 `dependencies` 声明 | 确保加载顺序正确，防止运行时空指针 |
| P1 | 统一 3 个插件的 ID (`folder_plugin`→`folder` 等) | 命名一致性；注意需要同步更新其他插件的依赖引用 |

### 第二批 — 推荐修复

| 优先级 | 修改 | 影响 |
|--------|------|------|
| P2 | 删除 8 个插件的空 `registerServices()` / `registerBlocs()` | 减少样板代码 |
| P3 | LuaPlugin：用 DI 替换全局 `hookRegistry` | 可测试性 |
| P4 | LuaPlugin：拆分 `onLoad` 方法 | 可维护性 |
| P5 | EditorPlugin：删除未使用的旧版 Hook 文件 | 减少混淆 |

### 第三批 — 建议改进

| 优先级 | 修改 | 影响 |
|--------|------|------|
| P6 | AIPlugin：`_migrateLegacySettings` 走 SettingsRegistry | 数据一致性 |
| P7 | Editor Hook：统一 `buildContent` 参数类型 | 类型安全 |
| P8 | 未设置 `enabledByDefault` 的插件显式声明 | 明确意图 |

---

## 4. 全局观察

### 4.1 架构优点

- **插件系统设计清晰**：PluginManager → ServiceRegistry → HookRoleRegistry 链路清晰
- **CQRS 模式一致**：所有写操作走 CommandBus，查询走 Repository/QueryBus
- **Hook 系统扩展性好**：类型安全基类 + 优先级排序 + API 通信
- **参考实现存在**：CorePlugin、SearchPlugin 可作为模板

### 4.2 系统层面改进建议

| 建议 | 说明 |
|------|------|
| `Plugin` 基类改进 | `registerServices()` / `registerBlocs()` 返回 `[]` 是默认值，多数插件不需要重写 |
| 全局 `hookRegistry` 消除 | 这是最大的遗留问题 —— 多处代码仍直接引用全局单例而非通过 DI |
| 插件 ID 校验 | 可添加 lint 规则或 PluginManager 加载时校验 ID 格式 |
| Hook 生命周期 | 当前仅 AppFrameInitializer 手动管理 RootLayoutHook 生命周期，可考虑 PluginManager 统一管理 |
| CI 检查 | 可为 `dependencies` 声明添加静态分析检查（使用了某插件服务但未声明依赖 → 警告） |
