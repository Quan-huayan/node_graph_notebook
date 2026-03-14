# Node Graph Notebook - 重构实施路线图

## 概述

本文档是架构重构的实施计划，详细描述如何从当前架构迁移到新的 BLoC + Command Bus 混合架构。

## 实施原则

1. **保留 BLoC** - BLoC 继续管理 UI 状态（何时刷新 UI）
2. **添加 Command Bus** - Command Bus 处理业务逻辑（如何执行操作）
3. **渐进式迁移** - 两个系统并行工作，逐步切换
4. **UI 层不变** - Widget 无需修改

---

## 实施路线图

### 阶段 1: 核心基础设施 (4-5 周)

**目标**：建立 Command Bus 和图数据库存储引擎

**任务**：
1. **Command Bus 实现**
   - 实现命令总线核心逻辑
   - 实现中间件管道
   - 实现 CommandContext
   - 编写中间件测试

2. **图数据库存储引擎**
   - 实现 WAL（Write-Ahead Log）
   - 实现 MemTable（Hash 索引）
   - 实现 SSTable（Immutable 存储）
   - 实现异步刷新机制
   - 实现布隆过滤器优化

3. **引用存储系统**
   - 实现前向引用存储
   - 实现反向引用索引
   - 实现引用树遍历
   - 实现传递闭包计算（基础版）

4. **版本控制**
   - 实现 Append-only 存储
   - 实现版本链管理
   - 实现历史清理功能

5. **并发控制**
   - 实现写操作队列（串行化）
   - 实现读操作无锁机制
   - 并发安全测试

**交付物**：
- `lib/core/commands/` (完整实现)
- `lib/core/database/storage_engine.dart`
- `lib/core/database/reference_storage.dart`
- `lib/core/database/version_manager.dart`
- `lib/core/database/concurrency_manager.dart`
- `test/core/commands/` (测试)
- `test/core/database/` (测试)
- 性能基准测试报告

---

### 阶段 2: 执行引擎和并发 (2-3 周)

**目标**：实现混合执行引擎

**任务**：
1. 实现 IO 执行器 (async/await)
2. 实现 CPU 执行器 (Isolate 池)
3. 实现 GPU 执行器 (WebGPU/OpenCL)
4. 实现智能路由逻辑
5. 性能基准测试
6. 并发压力测试

**交付物**：
- `lib/core/execution/` (完整实现)
- `benchmark/concurrency_test.dart`
- 性能测试报告

---

### 阶段 3: 图分区与可达性优化 (3-4 周)

**目标**：实现图分区和预计算可达性矩阵

**任务**：
1. **图分区算法**
   - 实现社区发现算法（Louvain 方法）
   - 实现图分区策略
   - 实现分区管理器
   - 实现跨分区边界索引

2. **完全图检测与压缩**
   - 实现完全图检测算法（Clique Detection）
   - 实现完全图压缩存储
   - 实现压缩可达性查询

3. **可达性矩阵预计算**
   - 实现分区级可达性矩阵
   - 实现矩阵压缩（Bitset + 完全图优化）
   - 实现矩阵增量更新
   - 实现跨分区路径查找

4. **GPU 加速（可选）**
   - 实现 GPU 图遍历着色器（WebGPU/OpenCL）
   - 实现 GPU 并行 BFS/DFS
   - 实现社区发现的 GPU 加速
   - 性能对比测试

5. **缓存优化**
   - 实现分区级缓存
   - 实现热点节点预取
   - 实现 LRU 缓存淘汰策略

**交付物**：
- `lib/core/database/partitioner.dart`
- `lib/core/database/reachability_matrix.dart`
- `lib/core/database/clique_detector.dart`
- `lib/core/execution/gpu_executor.dart`（可选）
- `lib/core/database/cache_manager.dart`
- 性能测试报告（分区效果、矩阵压缩率）
- GPU 加速效果报告

**成功指标**：
- 分区内可达性查询 < 5ms
- 跨分区查询 < 20ms
- 矩阵压缩率 > 90%
- 完全图识别率 > 80%（理想图结构）

---

### 阶段 4: Query Bus 和 CQRS (2 周)

**目标**：实现查询优化和物化视图

**任务**：
1. 实现 Query Bus
2. 实现核心 Read Model
3. 实现物化视图
4. 实现查询缓存
5. 事件驱动更新机制
6. 查询性能测试

**交付物**：
- `lib/core/queries/` (完整实现)
- `test/core/queries/` (测试)

---

### 阶段 5: 插件系统 (2-3 周)

**目标**：实现中间件和 UI Hook 系统

**任务**：
1. 实现插件注册表
2. 实现插件上下文
3. 实现中间件插件接口
4. 实现 UI Hook 系统
5. 插件生命周期管理
6. 迁移现有插件到新系统

**交付物**：
- `lib/plugins/` (新系统)
- `plugins/example/` (示例插件)
- 插件开发文档

---

### 阶段 6: Service 层迁移 (2-3 周)

**目标**：将现有 Service 层迁移到 Command 完全接管

**任务**：
1. 创建 NodeService 适配器
2. 创建 GraphService 适配器
3. 创建 LayoutService 适配器
4. 更新 BLoC 层使用 Command Bus
5. 更新 UI 层适配
6. 集成测试

**交付物**：
- `lib/core/services/adapters/`
- 更新的 `lib/bloc/`
- 更新的 `lib/ui/`
- `test/integration/` (集成测试)

---

### 阶段 7: 性能优化和测试 (2 周)

**目标**：优化性能，确保稳定性

**任务**：
1. 数据库查询优化
2. 缓存策略优化
3. 并发性能调优
4. 内存优化
5. 压力测试
6. 错误处理完善

**交付物**：
- 性能优化报告
- 压力测试报告
- 错误处理文档

---

### 阶段 8: 文档和发布 (1 周)

**目标**：完善文档，准备发布

**任务**：
1. 编写架构文档
2. 编写 API 参考文档
3. 编写插件开发指南
4. 编写迁移指南
5. 创建示例项目
6. 发布 v2.0.0

**交付物**：
- `docs/architecture.md`
- `docs/api_reference.md`
- `docs/plugin_guide.md`
- `docs/migration_guide.md`
- `plugin_template/`

---

### 阶段 9: UI 渲染性能优化 (3-4 周)

**目标**：优化 Flame 渲染以支持 < 100K 节点

**背景**：当前 Flame 架构无法支撑大规模节点渲染。本阶段通过视口剔除、LOD 系统和空间分区优化，将 Flame 的支撑能力从 < 1K 节点提升到 < 100K 节点。

**任务**：

1. **实现视口剔除（Viewport Culling）**：
   - 只渲染视口内的节点
   - 基于 Camera 视口计算可见区域
   - 动态加载/卸载节点组件

2. **实现 LOD（Level of Detail）系统**：
   - Placeholder（< 10px）: 渲染为小圆点
   - Compact（10-50px）: 只渲染标题
   - Normal（50-200px）: 标题 + 预览
   - Full（> 200px）: 完整内容
   - 根据缩放级别动态切换

3. **实现空间分区（Spatial Partitioning）**：
   - 使用四叉树（QuadTree）管理节点空间
   - 快速查询视口内的节点
   - 优化碰撞检测和事件处理

4. **实现对象池（Object Pooling）**：
   - TextPainter 对象池
   - Paint 对象缓存
   - 减少 GC 压力

5. **实现批量渲染（Batch Rendering）**：
   - 批量绘制相同类型的节点
   - 减少 Canvas 调用次数
   - 优化文本渲染

6. **添加性能监控**：
   - FPS 监控
   - 可见节点计数
   - 渲染时间统计
   - 内存使用监控

**交付物**：
- `lib/flame/components/cullable_node_component.dart`
- `lib/flame/components/lod_node_component.dart`
- `lib/flame/spatial/quadtree.dart`
- `lib/flame/pools/text_painter_pool.dart`
- `lib/flame/renderers/batch_node_renderer.dart`
- `lib/flame/performance/performance_monitor.dart`
- 更新的 `GraphWorld`（集成空间索引）
- 性能对比报告

**成功标准**：
- 10K 节点: > 30 FPS
- 50K 节点: > 20 FPS
- 100K 节点: > 10 FPS
- 内存使用: < 2GB（100K 节点）

**Note**: 这是 Flame 渲染的优化极限。对于 > 100K 节点，需要实施 Phase 10 的混合渲染方案。

---

### 阶段 10: 混合渲染架构 (6-8 周)

**目标**：实现 Flame + WebGL 混合渲染，支持无限规模（> 100K 节点）

**背景**：用户需求为 > 100K 节点，这超出了 Flame 的能力范围。本阶段实现混合渲染架构：
- **Flame（近景）**: < 1000 节点，完整细节和交互
- **WebGL（远景）**: > 1000 节点，简化形状，GPU 加速

**架构图**：
```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (Flutter)                       │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │         ViewModeController (BLoC)                  │    │
│  │  - 根据缩放级别和节点数量切换视图模式                │    │
│  └────────────┬───────────────────────────────────────┘    │
│               │                                            │
│      ┌────────┴─────────┐                                 │
│      ▼                  ▼                                 │
│  Near View          Far View                              │
│  (Flame)          (WebGL/Canvas)                          │
│  ┌──────────┐    ┌─────────────────┐                     │
│  │< 1000    │    │ 1000 - ∞        │                     │
│  │ nodes    │    │ nodes           │                     │
│  │          │    │                 │                     │
│  │ Full     │    │ Simplified      │                     │
│  │ detail   │    │ shapes          │                     │
│  │ Interactive│  │ GPU accelerated │                     │
│  └──────────┘    └─────────────────┘                     │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │         InfiniteCanvas (Orchestration)              │    │
│  │  - 平滑的视图切换                                  │    │
│  │  - 统一的坐标系                                    │    │
│  │  - 动态 LOD 切换                                  │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**任务**：

1. **实现视图模式控制器（ViewModeController）**：
   - 根据缩放级别和节点数量切换视图模式
   - Near 模式: 使用 Flame 渲染
   - Far 模式: 使用 WebGL 渲染

2. **实现 WebGL 渲染器（GraphWebGLRenderer）**：
   - 使用 WebGL 绘制大规模节点
   - GPU 实例化渲染（Instancing）
   - 着色器程序（Vertex + Fragment）
   - 顶点缓冲区管理

3. **实现无限画布（InfiniteCanvas）**：
   - 统一 Flame 和 WebGL 的坐标系
   - 平滑的视图切换动画
   - 无缝的缩放和拖拽体验

4. **实现平滑过渡（ViewTransition）**：
   - 淡入淡出动画
   - 保持视觉连续性
   - 性能优化（异步切换）

5. **实现统一坐标系统**：
   - Flame 和 WebGL 使用相同的坐标系
   - 世界坐标到屏幕坐标转换
   - 视口边界计算

6. **实现混合性能监控**：
   - Near 视角性能指标
   - Far 视角性能指标
   - 视图切换时间统计

**交付物**：
- `lib/ui/controllers/view_mode_controller.dart`
- `lib/flame/webgl/graph_webgl_renderer.dart`
- `lib/ui/widgets/infinite_canvas.dart`
- `lib/ui/transitions/view_transition.dart`
- `lib/core/coordinates/graph_coordinate_system.dart`
- `lib/flame/performance/hybrid_performance_monitor.dart`
- WebGL 着色器程序
- 性能基准测试报告

**成功标准**：
- 100K 节点: > 30 FPS（WebGL far view）
- 1M 节点: > 20 FPS（WebGL far view）
- 10M 节点: > 10 FPS（WebGL far view）
- Near view（Flame）: 完整交互性（< 1000 节点）
- 视图切换: < 100ms

**技术考虑**：
- **flame_webgl** 包用于 WebGL 集成
- **GPU 实例化**用于高效节点渲染
- **Level of Detail**自动切换
- **内存管理**处理大规模数据集
- **Fallback**到 Canvas（如果 WebGL 不可用）

**Note**: 这是最复杂的阶段，需要 WebGL 专业知识。如果自定义实现过于复杂，可以考虑通过平台通道使用现有的 WebGL 图库（如 vis.js、sigma.js）。

---

## 风险与挑战

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 数据库实现复杂度 | 高 | 分阶段实施，先简后繁 |
| GPU 加速兼容性 | 中 | 提供 fallback 到 CPU |
| 并发控制难度 | 高 | 使用成熟的锁机制 |
| 迁移成本 | 高 | 适配器模式，兼容旧接口 |
| 性能不达标 | 中 | 性能测试驱动，持续优化 |
| **大规模渲染** | **高** | **Phase 9 优化 + Phase 10 混合渲染** |
| **WebGL 复杂度** | **高** | **考虑使用现有库或平台通道** |

---

## 成功指标

### 技术指标
- **千万级节点支持**：10,000,000+ 节点的存储和查询
- **节点查询延迟**：< 1ms（Hash 索引，内存缓存）
- **可达性查询**：< 10ms（分区级预计算矩阵）
- **图遍历性能**：GPU 加速后 > 100x 提升
- **写入吞吐量**：> 10,000 ops/s（串行化写操作）
- **并发读取**：无锁设计，线性扩展
- **内存占用**：< 1GB（100 万节点，含缓存）
- **启动时间**：< 3s（索引加载）

### 性能基准
- **小规模**（< 10K 节点）：启动 < 1s，查询 < 1ms
- **中规模**（10K-100K 节点）：启动 < 2s，查询 < 5ms
- **大规模**（100K-1M 节点）：启动 < 3s，查询 < 10ms
- **超大规模**（1M-10M 节点）：启动 < 5s，查询 < 20ms

### 渲染性能指标
| 规模 | 解决方案 | 目标 FPS | 内存限制 |
|------|----------|---------|---------|
| < 1K | 当前 Flame | 60 | < 100MB |
| 1K-10K | Phase 9 优化 | 45-60 | < 500MB |
| 10K-100K | Phase 9 优化 | 10-30 | < 2GB |
| 100K-1M | Phase 10 WebGL | 20-30 | < 4GB |
| 1M-10M | Phase 10 WebGL | 10-20 | < 8GB |

### 开发者指标
- 插件开发时间 < 2 小时
- API 学习曲线 < 1 天
- 示例插件 > 5 个

### 用户指标
- 应用启动时间 < 2s
- 大文件加载时间 < 5s
- 崩溃率 < 0.01%

---

## 关键文件清单

### 新增核心文件
- `lib/core/commands/command_bus.dart`
- `lib/core/commands/command_middleware.dart`
- `lib/core/commands/command_context.dart`
- `lib/core/execution/execution_engine.dart`
- `lib/core/database/storage_engine.dart` (LSM Tree: WAL + MemTable + SSTable)
- `lib/core/database/reference_storage.dart` (前向 + 反向引用)
- `lib/core/database/partitioner.dart` (图分区算法)
- `lib/core/database/reachability_matrix.dart` (可达性矩阵压缩)
- `lib/core/database/clique_detector.dart` (完全图检测)
- `lib/core/database/version_manager.dart` (Append-only 版本控制)
- `lib/core/database/concurrency_manager.dart` (简化版 MVCC)
- `lib/core/database/cache_manager.dart` (分区级缓存)
- `lib/core/queries/query_bus.dart`
- `lib/plugins/plugin_registry.dart`
- `lib/plugins/ui_hooks.dart`

### Phase 9 新增文件
- `lib/flame/components/cullable_node_component.dart`
- `lib/flame/components/lod_node_component.dart`
- `lib/flame/spatial/quadtree.dart`
- `lib/flame/pools/text_painter_pool.dart`
- `lib/flame/renderers/batch_node_renderer.dart`
- `lib/flame/performance/performance_monitor.dart`

### Phase 10 新增文件
- `lib/ui/controllers/view_mode_controller.dart`
- `lib/flame/webgl/graph_webgl_renderer.dart`
- `lib/ui/widgets/infinite_canvas.dart`
- `lib/ui/transitions/view_transition.dart`
- `lib/core/coordinates/graph_coordinate_system.dart`
- `lib/flame/performance/hybrid_performance_monitor.dart`
- `lib/flame/webgl/shaders/` (WebGL 着色器)

### 修改现有文件
- `lib/app.dart` (依赖注入)
- `lib/bloc/node_bloc.dart` (使用 Command Bus)
- `lib/bloc/graph_bloc.dart` (使用 Command Bus)
- `lib/core/services/node_service.dart` (适配器)
- `lib/core/services/graph_service.dart` (适配器)

### 删除文件
- `lib/plugins/hooks/graph_plugin.dart` (旧插件系统)
- `lib/core/repositories/node_repository.dart` (被图数据库引擎取代)
- `lib/core/repositories/graph_repository.dart` (被图数据库引擎取代)
- `lib/core/repositories/file_system_node_repository.dart` (被图数据库引擎取代)
- `lib/core/repositories/file_system_graph_repository.dart` (被图数据库引擎取代)

---

## 验证计划

### 单元测试
- Command Bus 中间件管道测试
- 数据库 CRUD 操作测试
- 索引性能测试
- 并发安全测试

### 集成测试
- Command → Database 端到端测试
- 插件系统集成测试
- UI → Command 集成测试

### 性能测试
- 查询延迟测试
- 并发吞吐量测试
- 内存占用测试
- GPU 加速效果测试

### 渲染性能测试
- Flame 优化前后对比（Phase 9）
- WebGL 渲染性能测试（Phase 10）
- 视图切换性能测试
- 大规模节点渲染压力测试

### 压力测试
- **小规模**：10,000 节点加载和查询测试
- **中规模**：100,000 节点加载和查询测试
- **大规模**：1,000,000 节点加载和查询测试
- **超大规模**：10,000,000 节点加载和查询测试
- 并发写入测试（验证串行化队列）
- 长时间运行稳定性测试（24 小时）
- 内存泄漏测试
- 图分区效果测试（压缩率、查询性能）

---

## 下一步行动

1. ✅ 审查本路线图（已完成）
2. ⏭️ 确认阶段 1 的任务优先级
3. ⏭️ 创建详细的任务追踪（GitHub Issues）
4. ⏭️ 开始阶段 1 实施（Command Bus 基础设施）

---

**文档版本**: v2.0
**最后更新**: 2025-01-14
**维护者**: Node Graph Notebook 团队
