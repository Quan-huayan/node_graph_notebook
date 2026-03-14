# Node Graph Notebook - 设计文档总览

本文档目录包含 Node Graph Notebook 的详细架构设计文档，介于概念级和实现级之间。

## 文档导航

### 系统总览
- [系统架构设计](overview/system_architecture.md) - 整体架构、分层设计、组件职责
- [数据流设计](overview/data_flow.md) - 数据在系统中的流动路径
- [组件交互设计](overview/component_interaction.md) - 组件间的交互协议

### Phase 1: 核心基础设施
- [Command Bus 设计](phase1_core_infrastructure/command_bus.md) - 命令总线架构
- [存储引擎设计](phase1_core_infrastructure/storage_engine.md) - LSM Tree 存储引擎
- [引用存储设计](phase1_core_infrastructure/reference_storage.md) - 图引用存储机制
- [版本控制设计](phase1_core_infrastructure/version_control.md) - 版本控制机制
- [并发控制设计](phase1_core_infrastructure/concurrency.md) - 并发安全保证

### Phase 2: 执行引擎
- [执行引擎架构](phase2_execution/execution_engine.md) - 执行引擎总览
- [IO 执行器设计](phase2_execution/io_executor.md) - 异步 IO 执行器
- [CPU 执行器设计](phase2_execution/cpu_executor.md) - CPU 密集型任务执行
- [GPU 执行器设计](phase2_execution/gpu_executor.md) - GPU 加速执行

### Phase 3: 图分区优化
- [图分区算法](phase3_partitioning/graph_partitioner.md) - 图分区策略
- [可达性矩阵](phase3_partitioning/reachability_matrix.md) - 可达性计算
- [完全图检测](phase3_partitioning/clique_detector.md) - 完全图检测算法
- [缓存策略](phase3_partitioning/cache_strategy.md) - 分区缓存优化

### Phase 4: Query Bus (CQRS)
- [Query Bus 设计](phase4_cqrs/query_bus.md) - 查询总线架构
- [Read Model 设计](phase4_cqrs/read_models.md) - 读模型设计
- [物化视图](phase4_cqrs/materialized_views.md) - 物化视图策略

### Phase 5: 插件系统
- [插件架构](phase5_plugins/plugin_architecture.md) - 插件系统架构
- [中间件插件](phase5_plugins/middleware_plugins.md) - 中间件插件设计
- [UI Hook 系统](phase5_plugins/ui_hooks.md) - UI 扩展机制

### Phase 6: Service 迁移
- [Service 适配器](phase6_migration/service_adapters.md) - 现有 Service 适配层
- [BLoC 集成](phase6_migration/bloc_integration.md) - BLoC 状态管理集成
- [UI 适配](phase6_migration/ui_adaptation.md) - UI 层适配策略

### Phase 9: 渲染优化
- [视口剔除](phase9_rendering/viewport_culling.md) - 视口外剔除策略
- [LOD 系统](phase9_rendering/lod_system.md) - 细节层次系统
- [空间分区](phase9_rendering/spatial_partitioning.md) - 空间分区优化
- [对象池](phase9_rendering/object_pooling.md) - 对象池管理

### Phase 10: 混合渲染
- [视图模式控制](phase10_hybrid/view_mode_controller.md) - Canvas/WebGL 切换
- [WebGL 渲染器](phase10_hybrid/webgl_renderer.md) - WebGL 渲染实现
- [坐标系统](phase10_hybrid/coordinate_system.md) - 统一坐标变换

## 设计原则

### 1. 分层清晰
- 每个子系统有明确的职责边界
- 层间交互通过定义良好的接口
- 避免跨层直接依赖

### 2. 接口优先
- 所有子系统的公共 API 必须在设计中明确定义
- 接口定义包括类型签名、参数说明、返回值
- 接口变更需要经过设计评审

### 3. 性能意识
- 关键算法需要论文级别的描述
- 包含复杂度分析和性能考虑
- 明确性能目标和瓶颈

### 4. 并发安全
- 所有共享状态需要明确的并发控制策略
- 读操作尽可能无锁
- 写操作串行化保证一致性

### 5. 可测试性
- 设计支持依赖注入
- 关键组件可独立测试
- 提供测试替身（Mock）接口

### 6. 渐进式实现
- 每个阶段可独立实施和验证
- 支持增量迁移现有代码
- 保持向后兼容性

## 文档结构约定

每个设计文档遵循统一的模板：

```markdown
# [子系统名称] 设计文档

## 1. 概述
### 1.1 职责
### 1.2 目标
### 1.3 关键挑战

## 2. 架构设计
### 2.1 组件结构
### 2.2 接口定义

## 3. 核心算法
### 3.1 [算法名称]

## 4. 数据结构
### 4.1 [数据结构名称]

## 5. 并发模型

## 6. 错误处理

## 7. 性能考虑

## 8. 关键文件清单

## 9. 参考资料
```

## 术语表

| 术语 | 定义 |
|------|------|
| Command | 表示写操作的不可变对象，执行后会改变系统状态 |
| Query | 表示读操作的对象，不改变系统状态 |
| Command Bus | 负责分发和执行 Command 的中央管道 |
| Query Bus | 负责路由 Query 到对应 Read Model 的组件 |
| LSM Tree | Log-Structured Merge Tree，一种写优化的存储结构 |
| WAL | Write-Ahead Log，预写日志，用于崩溃恢复 |
| MemTable | 内存中的表结构，用于缓冲写入 |
| SSTable | Sorted String Table，磁盘上的不可变文件 |
| CQRS | Command Query Responsibility Segregation，命令查询职责分离 |
| MVCC | Multi-Version Concurrency Control，多版本并发控制 |
| Node | 系统中的基本数据单元，代表概念或内容 |
| Reference | Node 之间的有向关系 |
| Graph | Node 和 Reference 的集合 |
| Partition | Graph 的子集，用于优化性能 |
| Viewport | 当前可见的图形区域 |
| LOD | Level of Detail，细节层次 |

## 参考架构

### 当前架构（重构前）
```
UI Layer
    ↓
BLoC Layer
    ↓
Service Layer
    ↓
Repository Layer
```

### 目标架构（重构后）
```
UI Layer
    ↓
BLoC Layer (状态管理)
    ↓
├─ Command Bus ──┐
│                ↓
├─ Query Bus ────→ Execution Layer
│                ↓
└─ Execution Engine → Storage Layer
                     (LSM Tree + Reference Storage)
```

### 迁移策略
1. Phase 1-5: 建立新架构，与现有系统并行
2. Phase 6: 通过适配器将现有 Service 迁移到新架构
3. Phase 7-8: 清理旧代码，完全切换到新架构
4. Phase 9-10: 渲染层优化

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2025-01-14 | 初始版本，Phase 1 设计文档 |

## 维护指南

### 如何更新设计文档
1. 在实施过程中，如果发现设计与实现有偏差，及时更新设计文档
2. 设计文档变更需要经过评审
3. 保持设计文档与代码同步

### 如何添加新设计
1. 按照统一的模板创建新文档
2. 在本 README 中添加导航链接
3. 更新相关的术语表（如有新术语）

### 设计评审流程
1. 设计者创建设计文档
2. 团队成员评审设计
3. 解决评审意见
4. 设计批准后进入实施阶段

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
