# 02 — 模型与呈现

> 前置：[[00-philosophy]]（不变量唯一出处）| [[01-responsibilities]]（承诺清单）
> 本文定义数据模型（Node/Concept/Graph）、存储（两个存储域）、呈现系统（Hook/Hook Tree/窗口化/失效）。
> 本文只引用 00 的不变量，不重复定义。

---

## 一、数据模型

### 1.1 Node（逻辑层）

Node 是纯数据实体：逻辑身份 + 结构关系 + 内容引用。**不含 UI 信息**（00 不变量 4.3-5）。

```dart
abstract class Node {
  /// 逻辑身份（uuid），稳定
  String get id;

  String get title;

  /// 文本内容（markdown 等主内容），可为空
  String? get content;

  /// 有序引用集合：slot → targetId，仅 targetId（00 §2.2）
  Map<String, String> get references;

  /// 纯数据元信息，不含任何 UI 信息（00 不变量 4.1）
  Map<String, dynamic> get metadata;

  DateTime get createdAt;
  DateTime get updatedAt;

  Node copyWith({String? title, String? content,
                 Map<String, String>? references, Map<String, dynamic>? metadata});
}
```

**Node 不感知文件**（00 §3.4 的彻底落地）：物理文件是存储实现的序列化形态（FSTGraph 把 content 落盘为主内容文件），逻辑层接口不暴露任何物理概念。

**附加内容不是 Node 字段——附件 = 被引用的独立节点**（All is Node 推论）：图片/代码/3D/二进制是 asset 类 Concept 的实例，主节点用 references 引用它们。附件因此天然拥有 metadata、可被引用、可被打包，且任何后端（含 InMemoryGraph）行为一致。

### 1.2 Concept（代码层 schema）

Concept 定义一类 Node 的结构约束与行为。**不是 Node，不存储于 Graph**（00 §2.1）。Plugin 是唯一来源。

```dart
abstract class Concept {
  String get id;          // 全局唯一，如 'com.example.folder:folder'
  String get name;
  String get description;

  /// ---- 结构约束 ----
  Set<String> get slots;              // references key 必须属于此集合
  Set<String> get requiredSlots;
  Map<String, MetadataField> get metadataSchema;
  Set<String> get requiredMetadataKeys;
  ContentRequirement get contentRequirement;   // required | optional | none

  /// ---- 行为 ----
  bool validate(Node node);           // 纯结构匹配（00 不变量 4.3-1）

  Node createInstance({required String id, required String title,
                       String? content, List<FileRef>? fileRefs,
                       Map<String, String>? references,
                       Map<String, dynamic>? metadata});

  /// 呈现面：为 instance 创建 Hook，形态由 context.kind 决定
  Hook createHook(Node instance, HookContext context);
}
```

**Concept 接口必须"薄"**（01-E 承诺）：Lua 需能实现它（动态 Concept 引擎）。任何膨胀的接口都意味着 Lua 插件永远写不出来。

### 1.3 匹配优先序（确定性锚点）

归属判定 = 纯结构匹配 + 全序优先序（00 不变量 4.3）：

```
1. ConceptRegistry.findFor(node) 对全部已注册 Concept 执行 validate()
2. 命中多个 → 按特异性排序：requiredSlots ∪ requiredMetadataKeys 数量多者胜
3. 平局 → 注册序（先注册者胜）
4. 无命中 → 兜底 Concept（内置通用 schema：渲染为普通笔记，永不空洞）
```

全序优先序 + 纯结构匹配 ⇒ 结构确定性**与插件加载顺序无关、与 UIStateStore 无关**（00 不变量 4.3-4）。

### 1.4 环校验

- **执行点**：写命令的 Handler，落盘前（00 §2.3）
- **算法**：受影响子图增量 acyclicity 检查——新引用边 + 其可达闭包内做 DFS 找回边，O(受影响区域)
- **失败表现**：命令拒绝，抛 `CycleError`，用户文案："此操作会形成循环引用，已阻止"
- **预判**：drop 判定阶段即可拒绝（把 A 拖入 A 的后代，见 03）

### 1.5 Graph（结构存储抽象）

```dart
/// 后端存储的结构面。所有 Node 结构的唯一权威。
abstract class Graph {
  Node? get(String id);
  Node? getMany(List<String> ids);   // 批量读：物化窗口的读契约（10⁶ 下禁止逐点 N 次随机读）
  void save(Node node);
  void delete(String id);
  List<Node> getAll();
  List<Node> getByMetadata(String key, dynamic value);
}
```

读侧优化（批量合并、LRU 缓存、二级索引）归存储实现——QueryBus 的职责由"窗口化物化 + 批量读 + 实现层缓存"承接，不恢复总线抽象。

---

## 二、存储：两个存储域

> 逻辑上只有两个存储域（00 不变量 4.1-推论 1）：
> **后端存储** = Graph（结构） + 文件层（内容）；**前端存储** = UIStateStore（外观）。

### 2.1 文件层（内容，存储实现的物理形态）

物理层：数据根目录下的文件树，任意类型（md/代码/数据/3D/二进制），可被编辑器、git、脚本直接管理（00 §3.2）。

**文件层不是逻辑抽象**——它是 FSTGraph 的物理实现细节，逻辑层（Node 接口）完全不知道文件存在：

- 主内容文件：FSTGraph 把 Node.content 落盘（笔记 → `.md`），内容与结构分离（sidecar，§2.2）
- 附加内容：**不是 Node 字段，是独立节点**——图片/代码/3D 等 asset 类 Concept 的实例，被主节点以 references 引用（§1.1）
- 文件移动/重命名：别名表（`fileId → path`）更新——**移动文件 ≠ Node 失效**（00 §3.4）
- InMemoryGraph（测试/未来后端）无文件概念，逻辑行为与 FSTGraph 一致

### 2.2 结构存储（Node 的结构）

结构（title/references/metadata）与内容分离（00 §3.3，`.git` 哲学）。

- **倾向方案**：每 Node 一个 sidecar 结构文件（分区目录存放），内容文件自由分布在文件树中
- **分区策略（10⁶）**：sidecar 按 nodeId 哈希分区（`data/.node/ab/<id>.json`），避免单目录海量文件
- 最终物理形态 → architecture.md 第 6 章定

### 2.3 UIStateStore（外观）

```dart
/// 前端存储：外观状态。不含任何结构性数据（00 不变量 4.1）。
abstract class UIStateStore {
  dynamic get(String key);
  void set(String key, dynamic value);
  void remove(String key);
  Map<String, dynamic> getByPrefix(String prefix);
}
```

**键方案（修掉 `position.<nodeId>` 碰撞）**：一个 Node 可有多个 Hook（不同容器），键必须带容器上下文：

```
<domain>.<containerId>.<hookId>
position.graph.<folderId>        // 画布位置
expand.sidebar.<folderId>        // 侧边栏展开
camera.main.<rootHookId>         // 相机
selection.<containerId>.<hookId>
```

**孤儿 GC**：`getByPrefix` 时对照 Graph 的 nodeId 存在性，惰性清理不存在的键。孤儿不阻塞，只在触达时清理。

**失效语义（M7.2 回填，修 §3.4 自相矛盾）**：UIStateStore 写 = 外观直写（changeKind.ui 不发失效事件，架构 §5.2）——前提假设**写入方 = 渲染方**（画布自身拖动 = 本地直刷）。**外部写入方**（可见性对话框/未来插件/Lua）的变更必须到达渲染方：UIStateStore 提供**观察者通道**（`attach/detach(String key)`），渲染方（画布）自订阅关心前缀（如 `position.graph.`）。写进失效路径的是**数据变更**（Graph 写），外观直写不经过 UI 管理器——本句与 §3.4 的"数据变更（Handler 写 Graph / UIStateStore）"表述以本段为准（§3.4 同步修订）。

### 2.4 10⁶ 物理设计（原则）

1. **内容分区**：文件树按类型/哈希分区，单目录文件数有界
2. **懒加载**：Graph 结构按需读入（窗口化内存），不整体载入
3. **二级索引**：`getByMetadata` 需要物化索引（内存构建或文件层缓存）——architecture.md 第 6 章
4. **增量是唯一路径**：任何全量重建在 10⁶ 下是分钟级，设计上不存在

---

## 三、呈现：Hook 系统

### 3.1 Hook 契约（位置无关）

```dart
/// Hook 是 Node 的视图面（00 §6）。
abstract class Hook {
  String get nodeId;
  String get hookId;
  Map<String, Hook> get references;   // 只含 Hook，不含 Node

  /// 渲染自身。位置无关：可被渲染进任意 RenderContext——包括全局 overlay。
  /// 这是飞行壳层（03）成立的前提。
  void render(RenderContext context);
}

abstract class RenderContext {
  RenderContext createChildContext(Hook childHook);
}
```

**Hook 的边界**（承 00 不变量 4.3-5 / 4.4）：
- ✅ 主动读：读自己 Node.metadata
- ✅ 渲染自身（位置无关）
- ✅ 通过 references 组织子 Hook
- ❌ 读其他 Node 的 metadata
- ❌ 创建/修改/删除 Node（写一律走 Command → Handler）
- ❌ references 含 Node

### 3.2 Hook Tree = 渲染层次

- Hook.references 即递归结构：渲染 = Hook Tree 递归遍历
- 父 Hook 驱动子 Hook 的递归，**不代替子 Hook 渲染**
- 信息通道三个方向：父→子、子→父、容器→覆盖层（通道存在是架构，传递内容是实现）

**弹出对话框的归属（M7.2 回填，用户设计裁决）**：
- **弹出对话框 = 概念自治能力**：任何 Concept/插件可弹自己的对话框（settings/market/编辑表单均如此）——**谁弹谁负责外壳**（close/回收），无中心化外壳机制（不发明 appframe 统一容器）。
- **节点打开 = 渲染其 Hook 进发起方对话框**：打开节点 = 发起方（容器）弹对话框，内容 = 节点自己的 Hook 渲染（kind='open'，§1.2 形态由 kind 决定）；**画布打开 = CanvasConcept 责任**（画布容器提供外壳）；侧边栏打开 = 各插件自弹。打开呈现的完整性 = 各 Concept 自己的责任（容器 Concept 应提供自己的打开内容呈现——folder 打开 = 子级列表）。

### 3.3 窗口化（10⁶ 前提）

- **Hook 数量 ≈ 可视窗口，≠ 节点数**。10⁶ 节点不可能物化 10⁶ 个 Hook。
- 物化：UI 管理器按视口/容器驱动，按需实例化
- 回收：离开视口/容器关闭时回收
- 物化时读到的是新数据——**多数陈旧状态根本不会发生**（00 §4.4-4 的推论）

### 3.4 失效与增量

```
数据变更（Handler 写 Graph）
  → UI 管理器：nodeId → hookId 索引（全量内存可承受：10⁶ × 16B ≈ 16MB）
  → 广播：只达【已物化】的 Hook
  → Concept 反应：重读自己 Node.metadata → 重渲染
（UIStateStore 直写不进失效路由——外观直写，见 §2.3 失效语义：观察者通道。）
```

**三层增量粒度**（缺一不可，否则全量重建）：

| 层 | 粒度 | 机制 |
|---|---|---|
| 失效路由 | O(1) | nodeId→hookId 索引（UI 管理器拥有） |
| 树重挂 | 受影响子树 | 只重挂变更节点对应的 Hook 子树 |
| 重绘 | dirty Hook | 只重绘被通知的 Hook，下一帧 |

增量粒度的输入 = WriteResult 载荷（03 §四）：`changeKind: structure` → 树重挂；`data` → 重绘；`ui` → 外观直写。

- 未物化节点变更 = 索引更新一行，无渲染成本
- 通知按 nodeId 路由，**不整树广播**

### 3.5 被动读的所有权

- **路由 = UI 管理器**（索引、广播、物化协调）
- **反应 = Concept**（收到通知后重读 metadata → 重渲染）
- 索引的确定性：同一后端图 + 同一插件集 → 同一索引内容（00 不变量 4.3-4）

---

## 四、职责回填（01 执法规则 1）

新增概念已入矩阵：`HookContext`（context.kind 决定形态）。**修正记录**：`FileRef` / `FileRequirement` 已从模型移除——fileRefs 是 FilesystemNodeRepository 的物理需求，上浮进 Node 接口违背 00 §3.4"物理不污染逻辑"（实现上浮，单一实现绑架抽象接口）；附件统一为**独立节点**（asset 类 Concept 实例，被引用而非字段）。F 区遗留项状态：文件绑定（sidecar + 主内容文件）、分区（哈希分区）已定，见 architecture.md 第 6 章。
