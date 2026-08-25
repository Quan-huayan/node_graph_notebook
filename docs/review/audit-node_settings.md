# 审查文档：node_settings（设置插件）

- 路径：`packages/node_settings`｜扫描文件：11｜结论：**合规良好（1 violation / 3 warning / 1 info）**

## 摘要

依赖声明一致、无任何其它 node_*/app 依赖（R1 合规）；读写分离干净——lib 无 Graph 写调用，读侧仅
Graph 直读（get/getAll）+ Hook 呈现走 sink/物化（R2/R4/R14 合规），无 print/codegen/QueryBus，UI 文案
全部经 i18n.t()（R7/R11/R12 合规）。主要风险集中于 vault_settings.dart：裸 catch (error) 捕获任意异常
并把原始错误字符串直接展示给用户（R9 明确违规）；VaultManager 的新建/移除（移入 .trash）持久化写由 UI
表单直调、未走 CommandBus 且新建路径无失败反馈（R2/R3 设计气味，建议设计裁决注释或命令化）。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | **violation** | typed_exceptions | `lib/src/vault_settings.dart:188` | R9 | **裸 catch 吞任意异常**：`catch (error) { ... Text('$error') }` 把原始错误字符串直接展示给用户——内部错误文案外泄 + 静默降级风险；应捕获类型化异常（FileSystemException/VaultException 类）并映射为可读文案。 |
| 2 | warning | write_path | `lib/src/vault_settings.dart:148` | R2 | **仓库持久化写未走命令总线**：UI 表单直调 VaultManager.createVault/removeVault（vaults.json 持久化 + 数据移入 .trash），全程无 CommandBus/WriteResult.inverse/撤销/失效通知；若壳层服务直写属设计裁决，建议在文档注释中显式声明理由。 |
| 3 | warning | handler_discipline | `lib/src/vault_settings.dart:144` | R3 | **新建仓库失败无用户反馈**：_create 无 try/catch，createVault 失败将成 unhandled 异步异常，违反 05 纪律 8（错误路径必须含用户可见反馈）；建议与 _remove 一致补错误 SnackBar 或类型化异常处理。 |
| 4 | warning | service_resolution | `lib/settings_plugin.dart:78` | R13 | onLoad 保存 provider 快照（已核验）：主路径已用宿主注入 servicesProvider 缓解，快照仅作测试回退；并入总览 P1-5。 |
| 5 | info | import_order | `lib/src/vault_settings.dart:6` | R10 | 项目包先于 flutter（全仓惯例）；统一裁决（总览 P1-6）。 |

## 统计与建议

- 统计：violation 1｜warning 3｜info 1
- P0：#1 类型化 catch + 文案映射；#3 补失败反馈（05 纪律 8 直接相关）。
- P1：#2 设计裁决（仓库写是否命令化或声明壳层直写例外）。