# 审查文档：plugon（vendored 粘合层，上游资产）

- 路径：`packages/plugon`｜扫描文件：24（lib 12 + test 12）｜结论：**合规（0 violation / 1 warning / 3 info）**
  ——按 vendored 纪律处理：整体 git 跟踪、上游 117 测试为外部资产，仅轻量确认，不吹毛求疵。

## 摘要

零项目依赖（仅 flutter/provider/flutter_bloc），lib/core 纯 Dart 零 Flutter 且有结构守卫测试
（no_flutter_imports_test）锁定分层；117 个上游测试齐全（ownership/collection/provider/registry/
guard/contract/deps/lifecycle/exports/bloc），vendored 完整性确认。无 print、无异步 exists、
无 codegen、无 UI 硬编码中文（内部错误消息豁免）、服务经懒构建 provider 运行时解析不落快照。
R2–R5/R14 对本包不适用（不触图/存储/渲染）。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | warning | typed_exceptions | `lib/core/plugin/plugin_manager.dart:83` | R9 | 生命周期编排 6 处裸 catch (e)（83/137/195/207/241/247）：均记录 lastError 后 rethrow/继续清理，永不静默吞错，且插件回调可抛任意类型——vendored 编排器合理模式，建议加注释说明即可，无需改型。 |
| 2 | info | import_order | `test/flutter/bloc_providers_test.dart:1` | R10 | Flutter 组被第三方拆开（flutter_test 应排在第三方前）；vendored 测试风格级偏差。 |
| 3 | info | import_order | `test/flutter/providers_test.dart:4` | R10 | 第三方 provider 排在项目包之后；低风险风格偏差。 |
| 4 | info | file_structure | `lib/core/di/exceptions.dart:2` | R6 | di/plugin/extensions 三个 exceptions.dart 按域合并多类（异常按域聚合模式，文档注释完整）；vendored 内部模式可接受。 |

## 统计与建议

- 统计：violation 0｜warning 1｜info 3
- 无需整改动作；如需可补插件管理器裸 catch 的豁免注释（并入总览 P0-1 的豁免裁决）。

## 整改落实（2026 本次会话）

> 全量整改由 docs/review 总览 §7 统一裁决驱动（P0 类型化捕获 + P0-2 环校验 + P0-3 inverse 注释；
> P1-5 R13 测试兜底豁免 / P1-6 R10 import 顺序仓库惯例 / P1-7 R6 命令族聚合豁免；
> P2-8/P2-9 窗口化回收与象限索引缓存）。粘合层无代码级违规（warning/info 均已注释或按裁决豁免；
> 详见总览 §7）。CI 两工具 PASS 与 `dart analyze` 零 error/warning 为验收线。