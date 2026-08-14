# 04 — 组装与工程

> 前置：[[00-philosophy]] | [[01-responsibilities]] | [[02-model-presentation]] | [[03-interaction-signals]]
> 本文定义粘合层（ConceptRegistry / Plugin / DI / 生命周期降级）与工程执行（资产盘点 / 包结构 / 里程碑 / 验收）。

---

## 一、粘合层（基于 Plugon v2）

> 粘合层**采用 Plugon v2 作为实现基础**，不重新发明依赖管理。
> Plugon（`D:\Projects\Plugon`）是本生态的成熟基础设施：DI + 扩展点 + 插件生命周期，
> 117 测试，架构文档明确面向 Flowing UI / Hook 体系设计（"Hook 概念归 Flowing UI 所有"）。
> 它解决：服务注册与解析、扩展点贡献、owner 清理、拓扑序、状态机、回滚。
> 我们只补充图 UI 特有的机制：匹配优先序、窗口化、失效、兜底、拖拽、存储。

### 1.1 概念对齐

| 机制 | 归属 |
|---|---|
| DI（ServiceCollection / ServiceProvider） | Plugon |
| 扩展点（ExtensionPoint / ExtensionRegistry） | Plugon |
| 插件生命周期（PluginManager：拓扑序/状态机/回滚/owner 清理/并发占位） | Plugon |
| **Concept 注册** | Plugon（Concept 作为 `ExtensionPoint<Concept>` 贡献，owner 清理自动随插件卸载） |
| **Concept 匹配**（findFor 优先序 + 兜底） | 我们（查询侧，00 不变量 4.3） |
| **CommandHandler 注册** | Plugon（`ExtensionPoint<CommandHandler>` 贡献） |
| **Command 路由**（dispatch） | 我们（CommandBus 查询侧） |
| 窗口化 / 失效 / 拖拽 / 存储 | 我们（Plugon 无此能力） |

### 1.2 DI 契约（Plugon）

关键语义（详见 Plugon `docs/ARCHITECTURE.md` §3）：

- **注册**：`addSingleton / addTransient / addScoped` + `For<TService, TImpl>` 双类型变体 + `tryAdd*` 系列 + `addInstance`；`owned(id)` 盖章视图自动打 owner 标记
- **解析**：`get<T>()`（last-wins）/ `getAll<T>()`（注册序，多实例）/ `tryGet<T>()`；解析键 = 注册时静态类型，精确匹配
- **lifetime**：singleton 根缓存跨 scope 共享（工厂收根 provider，杜绝跨代捕获）；transient 每次新建（可清理实例被当前 scope 追踪，逆创建序清理）；scoped 按 scope 缓存
- **循环依赖**：`CircularDependencyException`（解析栈 + 完整链路），绝不栈溢出
- **销毁规则**：优先 onDispose 回调，否则实例实现 Disposable；**逆创建序**；`disposeOwner(id)` 幂等（销毁已实例化实例 + 移除描述符），**不泄漏**
- **Flutter 适配槽位**：`isNotifier / isBloc / providerFactory` 纯 Dart 标记，Flutter 扩展注册时捕获类型化闭包——core 零 Flutter 依赖（结构守卫测试）
- **契约**：禁止在服务字段中保存 `sp`（provider 泄漏）；开放泛型不支持（Dart Type 不透明，按闭包类型逐个注册）

### 1.3 Plugin（Plugon 对齐）

```dart
abstract class Plugin {
  PluginMetadata get metadata;   // id / name / dependencies / enabledByDefault

  /// 方法式注册（v1 的返回列表已废弃）——owned 视图盖章
  void registerServices(ServiceCollection services);
  void registerExtensions(ExtensionRegistry extensions);  // Concept/CommandHandler 贡献

  Future<void> onLoad(PluginContext context);
  Future<void> onEnable();
  Future<void> onDisable();
  Future<void> onUnload();
}
```

生命周期编排（拓扑序启用、逆序卸载、依赖循环检测、错误策略、加载失败回滚、并发占位）**全部由 Plugon PluginManager 提供**，不重复实现。

### 1.4 ConceptRegistry（查询侧）

```dart
/// Concept 注册/注销归 Plugon 扩展点机制（removeOwner 自动清理）——
/// 我们只实现查询侧：全序匹配优先序 + 兜底（00 不变量 4.3）。
abstract class ConceptRegistry {
  Concept? findFor(Node node);               // 特异性（required 约束数）→ 注册序；无命中 → 兜底
  List<Concept> findByMetadata(String key, dynamic value);
}
```

### 1.5 生命周期与降级渲染

```
loadPlugin(id):  占位(并发保护) → registerServices(owned(id)) → registerExtensions
                 → onLoad → [enabledByDefault] enablePlugin
enablePlugin:    依赖拓扑序（DFS + visiting 集，循环 → PluginDependencyCycleException）
                 → onEnable → 贡献激活（扩展点 setPluginActive）
disablePlugin:   onDisable → 贡献停用
                 → 降级渲染：该插件 Concept 停用 → findFor 无命中 → 兜底 Concept 渲染为普通笔记
                 → 永不空洞、永不崩溃（00 不变量 4.3-3）
unloadPlugin:    逆拓扑 → onDisable(若已启用) → onUnload
                 → services.disposeOwner(id)（销毁已实例化实例 + 移除描述符）
                 → extensions.removeOwner(id)（移除 Concept/Handler 贡献）
                 → UIStateStore 孤儿键惰性 GC（02 §2.3）
错误策略:        load/enable 快速失败（lastError + error 态 + 重抛）；
                 unload 逐阶段捕获继续清理；永不静默丢弃
```

**Lua 插件**：动态 Concept 引擎——脚本化 Concept（createHook / Handler 用 Lua 实现）。Concept 接口"薄"是它可实现的保证（01-E 承诺，02 §1.2）。

---

## 二、资产盘点（旧 16 包）

| 处置 | 资产 | 说明 |
|---|---|---|
| **带走** | Flame 渲染栈（graph 插件的 flame/：graph_widget、components、lod、spatial_index、view_frustum_culler、node_drag_controller、drag_feedback） | 画布渲染、LOD、视锥裁剪、空间索引——10⁶ 的核心资产（**M7+ 资产，现渲染栈 = InteractiveViewer**；LOD/裁剪/10⁶ 验证 [计划]，01 #54） |
| 带走 | QuadTree（appframe/graph/quad_tree.dart） | 空间索引 |
| 带走 | 布局算法（layout 插件的增量布局引擎） | 布局启发式 |
| 带走 | i18n 翻译资源（i18n 插件） | 文案资产 |
| 带走 | Lua 运行时引擎与沙箱（lua 插件的 service/） | **API 层重写**（旧 registerHook 等全部作废） |
| 带走 | 执行引擎（core/execution） | 重构后接入渲染循环 |
| 带走 | 中间件实现（logging/undo/validation/transaction） | 作为 CommandBus 实现层的中间件管道（03 §四） |
| **烧掉** | NodeTemplate / NodeAttachment / UIHookNode / Role / Act | 00 删除清单 |
| 烧掉 | 旧 Hook 系统（hook_base/registry/context/metadata…） | 00 删除清单，一律转新 Hook |
| 烧掉 | QueryBus / EventBus 抽象 | 00 删除清单 |
| 烧掉 | 旧 CQRS 命令模型（Command.execute / 旧 Handler 体系） | 重构为纯 DTO + Handler（03 §四） |
| 烧掉 | 旧存储模型（NodeReference / Connection / RelationshipNode） | 00 删除清单 |

**盘点原则**：带走的是算法与资产（知识），烧掉的是模型与机制（结构）。重写不是失忆，但结构必须重建。

---

## 三、包结构（参照现行分层，依赖单向无环）

```
core_data        纯模型接口：Node / FileRef / Concept / Graph / UIStateStore / Hook 契约
                 零平台依赖（不 import dart:ui / flutter）
core             机制：匹配优先序 / 兜底 Concept / 环校验 / nodeId→hookId 索引 / 失效路由
                 / CommandBus / Handler / ConceptRegistry（查询侧）/ UI 管理器（物化/窗口化策略）
                 / 依赖 plugon（DI / ExtensionRegistry / PluginManager，见 §一）
appframe         Flutter 壳：RenderContext 实现 / Hook 物化器 / 窗口化 / DragController / FlightShell
                 / 存储实现（文件层 + sidecar + UIStateStore）
plugins/*        folder / graph / editor / ai / lua / converter / search / i18n / settings / market / data_recovery
```

```
core_data ← core ← appframe ← plugins/*
```

**约束**：
1. 依赖单向无环——CI 校验（脚本检查 import 方向，任一反向依赖即失败）
2. UI 管理器（物化/窗口化/失效路由）在 **core**（机制不依赖 Flutter），Flutter 壳只在 appframe——Lua 与测试可在 core 层直接使用机制
3. plugins 只依赖 appframe 与 core，互相不依赖（插件间通信走 Command/索引，不走直接依赖）

---

## 四、里程碑

```
M0 文档冻结：本套文档全部完成 + 01 职责矩阵回填完毕 + 无"属实现层"藏匿决策
M1 抽象层包：core_data + core 接口（纯 interface，零平台依赖，可单测）
M2 数据与存储：文件层 + sidecar + Graph 实现 + UIStateStore + 匹配优先序 + 兜底 + 环校验
M3 呈现：Hook 物化 / Hook Tree 遍历 / 位置无关渲染 / 窗口化雏形 / 失效索引
M4 交互：DragController / FlightShell / drop 语义判定
M5 插件化：引入 Plugon（DI + ExtensionRegistry + PluginManager 编排）/ 降级渲染 / 启动序列
M6 folder 插件（试金石）：端到端场景验收 + 旧包冻结归档
M7+ AI 场景 / Lua 动态 Concept / 其余插件 / 旧包删除
```

**M6 是试金石**：folder 插件浓缩全部争议——UI 结构持久化（投影不变式）、侧边栏拖拽=数据命令（三档判据）、环校验（拖 A 进 A 的后代）。folder 跑通 = 架构主张被验证。

---

## 五、验收标准

1. **端到端场景走查**：杀手演示（拖笔记进 AI 节点 → 变对话）每一步有唯一 owner + 唯一存储，落不出矩阵
2. **10⁶ 基准**：增量重建毫秒级、失效广播只达已物化 Hook、首帧渲染在预算内
3. **契约测试**：抽象层每个接口一条契约测试（core_data + core），纯 Dart 可跑
4. **依赖无环**：CI 校验通过
5. **不变量验证**：投影不变式（前端结构零持久化）、永不空洞（兜底渲染）作为测试断言

---

## 六、职责回填（01 执法规则 1）

新增概念：`CycleError`（03 已记）、`CommandResult`（Handler 返回契约）、`DragController`（拖拽事务生命周期）。**重大采用**：粘合层基于 Plugon v2——DI（ServiceCollection/ServiceProvider）、扩展点（ExtensionRegistry）、生命周期编排（PluginManager）全部归 Plugon；我们只保留 Concept 匹配（查询侧）、CommandBus 路由、降级渲染。包结构已定：三包族（core_data / core / appframe）+ plugins/*，依赖无环 CI 校验。仓库策略：同仓库并行，M6 旧包冻结归档，M7+ 删除，git 历史保留。
