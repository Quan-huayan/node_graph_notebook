# 审查文档：node_lua（Lua 插件）

- 路径：`packages/node_lua`｜扫描文件：11｜结论：**合规度较高（0 violation / 8 warning / 3 info）**

## 摘要

依赖方向与声明一致（仅 core/core_data/appframe/plugon/ffi，无 node_* 互依）；写操作最终唯一执行者
仍是经 commandHandlerPoint 注册的 Dart LuaWriteHandler（R2 主体合规），create/update 写引用前均经
AcyclicChecker（R3a），失败抛类型化异常（StateError/CycleError），坏脚本隔离与引擎不可用降级
（onLoad 捕获 LuaEngineException 后无脚本降级、不崩启动）落地，existsSync / 无 build_runner /
R11 文案豁免均已确认，执行超时未实现已在文件头显式标注 [计划]。
主要风险集中在**宿主写通道的网关纪律弱化**（绕过 dispatch、写后广播粒度恒 structure、双广播）、
**删除无级联**（与 node_graph 级联语义不一致）与**单引擎静态全局**约束。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | warning | write_path | `lib/lua_plugin.dart:199` | R2/R3b/R14 | **写后广播粒度硬编码 structure**：host 写返回串固定 'structure'，LuaWriteResult.changeKind 恒为 structure——纯 data 变更也按结构粒度广播（过度失效）；脚本命令内嵌 host.node_* 时宿主路径 notifyListeners 与外层 dispatch 各广播一次（双失效事件）。建议按动作推断粒度并统一单次广播。 |
| 2 | warning | write_path | `lib/lua_plugin.dart:185` | R2 | **宿主写直调 Handler 绕过 dispatch**：_hostWriteSync 直调 _writeHandler.applySync + 手动 notifyListeners；C 回调无法 await 的理由已注释，功能语义等价，但网关纪律弱化（插件停用后存活引用仍可写）。建议显式化为总线可见契约或注明豁免范围。 |
| 3 | warning | service_resolution | `lib/lua_plugin.dart:59`（已核验） | R13 | onLoad 保存服务快照并作缺省回退（L139 `_servicesProvider?.call() ?? _snapshot!`）；生产经 servicesProvider 运行时求值优先，但直接 new LuaPlugin() 装配或 vault 热切换会静默回退旧快照。并入总览 P1-5。 |
| 4 | warning | undo_inverse | `lib/src/lua_commands.dart:103` | R3(c) | LuaWriteResult.inverse => null 未注释不可撤销理由（同文件 LuaCommandResult L44 有注释）；补齐。 |
| 5 | warning | design_smell | `lib/src/lua_handlers.dart:174` | — | **Lua 删除无级联清理**：_delete 直调 graph.delete 不清反向引用，与 node_graph DeleteNodeHandler 级联语义不一致——脚本删节点后引用方（文件夹成员/连接边）悬空。建议委托级联语义或文档化「Lua 删除为裸删」约束。 |
| 6 | warning | handler_discipline | `lib/lua_plugin.dart:77` | R9 | 裸 catch 兜底模式（lua_plugin L77/84/91、lua_engine L52/L171）：FFI 回调边界不得向 C 抛异常有工程理由，但未收窄也未注释豁免；建议 on LuaEngineException 收窄或标注豁免理由。 |
| 7 | warning | import_order | `test/lua_plugin_test.dart:14` | R10 | flutter_test 排在项目包之后；全仓同模式，统一裁决（总览 P1-6）。 |
| 8 | warning | design_smell | `lib/src/lua_engine.dart:183` | — | **单引擎静态全局分发**：_currentEngine 与 LuaRuntime.lua/lastPrintOutput 静态可变，多引擎并存时 C 回调分发与 print 捕获串台（测试已并存）；文档标注 M7 单引擎约束，建议以回调 userdata/实例字段承载引擎上下文。 |
| 9 | info | other | `lib/src/lua_engine.dart:24` | R6 | 超时常量 luaDefaultTimeout 死代码（[计划] 标注合规）；注「未生效」防误解；无超时下坏脚本（while true）会卡死 UI 主线程——已知限制。 |
| 10 | info | design_smell | `lib/src/lua_engine.dart:280` | — | toLuaLiteral 对 Map 键直接插值（键含引号可注入 Lua 代码）；当前键来源受控风险低，建议与值一样转义。 |
| 11 | info | other | `lib/src/vendor/lua_runtime.dart:90` | — | registerFunction 的 toNativeUtf8 指针未 malloc.free（每注册一个宿主函数泄漏一份，有界）；建议用完释放。 |

## 统计与建议

- 统计：violation 0｜warning 8｜info 3
- P0：#1/#2 写通道网关纪律（广播粒度 + dispatch 绕过）建议与 #5 级联语义一并设计裁决；
- P1：#3/#4/#6/#7 并入总览批量项；P2：#8 多引擎隔离（M7+）、#10/#11 低风险修。

## 整改落实（2026 本次会话）

> 全量整改由 docs/review 总览 §7 统一裁决驱动（P0 类型化捕获 + P0-2 环校验 + P0-3 inverse 注释；
> P1-5 R13 测试兜底豁免 / P1-6 R10 import 顺序仓库惯例 / P1-7 R6 命令族聚合豁免；
> P2-8/P2-9 窗口化回收与象限索引缓存）。本文件各违规项落实状态：**已整改**（代码注释均引用本
> 文件 audit 编号与总览 §7 行号，可溯源）。仅标 [计划] 的规模项（如每帧全扫、getAll×N）保持注释，
> 未改实现。CI 两工具 PASS 与 `dart analyze` 零 error/warning 为验收线。