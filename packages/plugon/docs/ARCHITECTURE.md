# Plugon 架构文档

> 版本 2.0.0（2026-08-01，彻底重设计）。取代 `.trae/specs/plugin_system_extraction/` 中的 v1 设计。

## 1. 定位

Plugon 是 Flutter 应用内部的**依赖管理基础设施**，处于自研 **Flowing UI**（图结构 UI：All is Node / Hook = Node 视图）生态中。它负责三种依赖关系：

| 关系 | 机制 | 模块 |
|------|------|------|
| 插件间依赖（生命周期） | 声明式依赖 + 拓扑序启用 + 逆序卸载 + 循环检测 | `core/plugin` |
| 服务间依赖（DI） | .NET 风格容器：懒解析、生命周期、owner 清理 | `core/di` |
| 扩展点与贡献者 | 类型化 `ExtensionPoint<T>` + 优先级排序 + 插件状态驱动激活 | `core/extensions` |

**"Hook" 概念归 Flowing UI 所有**，Plugon 不占用该术语——Flowing UI 的 Hook 体系（Hook = Node 视图）基于 `ExtensionPoint<T>` 构建。

## 2. 分层

```
┌─────────────────────────────────────────────────┐
│  Flowing UI（独立框架，构建于扩展点之上）           │
├─────────────────────────────────────────────────┤
│  lib/flutter/（可选适配）                         │
│    collection_ext  addNotifier/addValue/addBloc  │
│    providers       buildProviders                │
│    bloc            buildBlocProviders            │
├─────────────────────────────────────────────────┤
│  lib/core/（纯 Dart，零 Flutter 依赖——有结构守卫测试）│
│    di           ServiceCollection/Provider        │
│    extensions   ExtensionPoint/Registry           │
│    plugin       Plugin/PluginManager              │
└─────────────────────────────────────────────────┘
```

- **core 永不导入 Flutter**：`test/core/no_flutter_imports_test.dart` 扫描源文件强制执行。
- 依赖方向：`core/plugin → core/di, core/extensions`；`core/extensions`、`core/di` 互相独立；`flutter/* → core/*`。
- `package:plugon/plugon.dart` 仅 core；`package:plugon/plugon_flutter.dart` 为 core + 适配。

## 3. DI 契约（.NET 风格）

```dart
final collection = ServiceCollection();
collection.addSingleton<Foo>((sp) => Foo(sp.get<Bar>()));   // 显式工厂注入
collection.addSingletonFor<IFoo, Foo>(construct: Foo.new);  // 接口/实现分离（无参构造）
collection.addSingletonFor<IFoo, Foo>(factory: (sp) => Foo(sp.get<Bar>())); // 需注入
collection.addTransient<Baz>((sp) => Baz());
collection.addScoped<Qux>((sp) => Qux());
final provider = collection.build();
provider.get<Foo>();     // 懒解析；未注册抛 ServiceNotFoundException
provider.get<IFoo>();    // 双类型注册：接口与实现两个键解析到同一实例
provider.getAll<IFoo>(); // 同类型全部注册（注册序）
```

- **解析键 = 注册时的静态类型**（精确匹配，无子类型解析）。
- **懒加载**：`build()` 不实例化任何东西；工厂在首次 `get` 执行。
- **重复注册（last-wins）**：同一类型允许多次注册（.NET 语义）；`get<T>()` 返回**最后一个**注册，`getAll<T>()` 返回全部（按注册序，对应 .NET 的 `IEnumerable<T>`）。多插件贡献同类型多实例（如多个 handler）是受支持场景；测试可用后续注册覆盖实现（Mock）。
- **双类型注册** `addSingletonFor<TService, TImpl>`（含 transient/scoped 与 tryAdd 变体）：注册接口与实现，两个类型都解析到同一实例（`.NET AddSingleton<TService, TImpl>` 的 Dart 等价物，并额外允许按实现类型解析）。`construct:` 接受无参构造器 tear-off（如 `Foo.new`）——纯 Dart 无反射，这是 .NET 自动构造最近的等价物。**分裂陷阱**：同一具体类型既作别名又单独注册时，两个键各自 last-wins，会解析到不同实例。
- **TryAdd 系列**：`tryAddSingleton` 等——类型已注册则 no-op（供框架/插件注册可选默认而不冲突）；双类型变体同时检查 service 与 impl 两个键。
- **lifetime**：`singleton`（根缓存，跨 scope 共享；**工厂收到根 provider**，工厂内 `sp.get` 解析 scoped 依赖命中根级缓存，杜绝从请求方 scope 跨代捕获）/ `transient`（每次新建；实现 `Disposable` 或带 `onDispose` 的实例被当前作用域追踪，作用域销毁时逆创建序清理）/ `scoped`（按 scope 缓存，scope 销毁时销毁；从根解析退化为根级实例，`build(validateScopes: true)` 可开启硬性报错）。
- **循环依赖**：工厂内经 `sp.get` 间接依赖自身时抛 `CircularDependencyException`（含完整链路），而非栈溢出。检测按描述符身份进行——别名键命中同一描述符视为同一节点。
- **销毁规则**（`disposeOwner`/`dispose` 时）：优先描述符的 `onDispose` 回调；否则实例实现 `Disposable` 接口时调用其 `dispose`；按**逆创建序**（.NET reverse creation order）。
- **owner 清理**：`disposeOwner(pluginId)` 销毁该 owner 已实例化且被追踪的实例（根单例 + 所有活跃 scope 的 scoped/可追踪 transient）并移除描述符；幂等；只清理实际实例化的实例。
- **注册方法返回 `ServiceCollection`**，支持链式。
- **开放泛型（open generic）不支持**：Dart 的 `Type` 运行时不透明（无 mirrors），无法像 .NET `AddSingleton(typeof(IRepo<>), typeof(Repo<>))` 注册原始泛型——需按闭包类型逐个注册（`IRepository<User>`、`IRepository<Order>` 各自一条）。
- **禁止在服务字段中保存 `sp`（provider）**——会造成容器泄漏与跨代引用。

## 4. 扩展点模型

```dart
const toolbar = ExtensionPoint<ToolbarItem>('toolbar');   // 身份：(Type, id)
registry.registerExtensionPoint(toolbar);                  // 重复注册抛异常
registry.addContribution(toolbar, item, priority: 100, ownerPluginId: 'p1');
registry.getActive(toolbar);  // 排序：priority 升序，注册序破平
```

- **激活由插件状态派生**：`setPluginActive(id, bool)` 开关整个插件的贡献，无每贡献状态机。宿主贡献（owner 为 null）始终活跃。
- `getAll` 含非活跃贡献；`getActive` 只含活跃贡献。
- 卸载清理用 `removeOwner(pluginId)`（移除贡献与激活状态）；扩展点本身是声明契约，卸载不删除。
- 同 id 不同泛型类型是不同扩展点（键 = (Type, id)）。
- **跨插件 API 不再用动态 map**（v1 的 `exportAPIs()` 已删除）——统一走类型化 DI 查询：`context.get<MyService>()`。

## 5. 插件生命周期

```
loadPlugin:  占位(并发保护) → registerServices(owned 视图) → registerExtensions
             → onLoad → [enabledByDefault] enablePlugin
enablePlugin: 依赖拓扑序先启用（DFS + visiting 集，循环 → PluginDependencyCycleException）
             → onEnable → extensions.setPluginActive(true)
disablePlugin: onDisable → extensions.setPluginActive(false)
unloadPlugin: 先卸依赖者（逆拓扑）→ onDisable(若已启用) → onUnload
             → services.disposeOwner → extensions.removeOwner → 移除
```

- **错误策略**：load/enable 快速失败（`lastError` + `PluginState.error` + 重抛）；unload 逐阶段捕获继续清理，最后重抛首个错误；`dispose()` 聚合重抛。**永不静默丢弃**。
- **加载失败回滚**：移除插件、回滚服务与扩展注册，可从 map 重试。
- **并发安全**：占位在任何 `await` 之前插入，重复加载抛 `PluginAlreadyLoadedException`。
- **状态机**：`unloaded → loaded → enabled ⇄ disabled`，任一步失败 → `error`。

## 6. Provider / Bloc 适配（flutter 层）

**关键约束**：Dart 运行期无法从 `Type` 构造泛型 widget（`Provider<T>` 的 T 必须在注册点静态已知）。因此 core 描述符带**不透明 `providerFactory` 槽位**，flutter 扩展方法在注册时捕获类型化构造闭包：

```dart
// lib/flutter/collection_ext.dart
collection.addNotifier(_Notifier());              // ChangeNotifierProvider.value，DI 销毁
collection.addNotifierSingleton((sp) => ...);     // ChangeNotifierProvider(create:)，树销毁
collection.addValue(_Service());                  // Provider.value，DI 销毁
collection.addFactory((sp) => ...);               // Provider(create:)，DI 销毁

// lib/flutter/bloc.dart
collection.addBloc((sp) => MyBloc());             // BlocProvider.value，DI 关闭
```

**销毁归属规则**（避免双重销毁）：

| 注册方式 | Provider 形态 | 销毁者 |
|---------|--------------|--------|
| addNotifier / addValue（实例） | `.value` | DI（onDispose 回调） |
| addNotifierSingleton | `create:` | widget 树 |
| addFactory | `create:` | DI（若实现 `Disposable`） |
| addBloc | `.value` | DI（close） |

- `buildProviders(provider, {activeOwners})` → MultiProvider 列表；`buildBlocProviders` → MultiBlocProvider 列表。`activeOwners` 排除禁用插件的服务（宿主服务始终保留）。
- bloc/notifier 都是 DI 单例，多次调用 build 返回同一实例（修复 v1 每次新建的缺陷）。
- **已知边界**：插件卸载时 DI 销毁其实例，已挂载的 widget 若仍引用会持有已销毁对象——正常流程是卸载先于子树销毁。
- **已知边界**：同一类型重复注册时，各描述符的 widget provider 都包装 `sp.get<T>()`（last-wins 实例）——Provider 类型相同、功能无损，但较早注册的 provider 不会展示其专属实例（同类型多 widget provider 本就是病态用法）。

## 7. 与 Flowing UI 的衔接

- Flowing UI 的 Hook（Node 视图）体系在 Plugon 之上构建：`ExtensionPoint<Hook>` 由 Flowing UI 定义，各插件 `addContribution` 贡献。
- Flowing UI 自身（Node/NodeReference/Role/约束/布局）是独立框架，不依赖 Plugon 的具体类型。
- 插件粒度混合：服务、UI 组件、功能模块均可通过 服务注册 + 扩展点贡献 表达。

## 8. 迁移指南（v1 → v2）

旧 host（如 archived `node_graph_notebook`）迁移要点：

| v1 | v2 |
|----|----|
| `package:plugin/...` | `package:plugon/plugon_flutter.dart` |
| `Plugin.registerServices()` 返回列表 | `registerServices(ServiceCollection)` 方法式注册 |
| `registerHooks()` / `HookRoleBase` | `registerExtensions(ExtensionRegistry)` + `ExtensionPoint<Hook>`（Flowing UI 定义） |
| `getHookWrappers(point)` | `extensions.getActive(point)` |
| `registerBlocs()` + `generateBlocProviders()` | `services.addBloc(...)` + `buildBlocProviders(...)` |
| `generateProviders()` | `buildProviders(...)` |
| `HookPriority` 枚举 | `int priority` |
| `HookAPIRegistry` / `exportAPIs()` | 类型化 DI 查询 |

## 9. Example 与集成测试

`example/`（独立包 `plugon_example`，`path: ../` 引用 plugon）是最小演示应用，
**含全部六平台工程目录**（android/ ios/ web/ windows/ macos/ linux/）：

- **3 个插件**：`core`（注册 SettingsService + 声明工具栏扩展点）、`status`（贡献只读条目）、`counter`（依赖 core，注册 CounterBloc 并贡献可交互条目）
- **宿主组装**：`PluginManager` → `buildProviders` + `buildBlocProviders` 接入 widget 树 → `extensions.getActive(toolbarItems)` 渲染扩展点（即 Flowing UI 消费 Hook 的模式）
- **集成测试** `example/test/app_test.dart`（widget 级，无需设备）：加载 → 依赖启用 → 扩展点渲染 → bloc 交互 → 禁用/启用 → 卸载清理全链路
- **平台验证**：Windows 与 Web 已在本机构建成功；Android 工程就绪（构建需可达 `dl.google.com`，国内网络见 `example/README.md` 的网络说明，含阿里云镜像配置与 JDK 17/21 要求）；iOS/macOS 需 macOS 机器、Linux 需 Linux 机器
- example 曾抓出真实 core bug（`tryGet` 绕过单例缓存新建实例）——现已有 core 回归测试

```bash
cd example && flutter test    # 4 个集成测试
flutter build windows         # Windows 构建（本机已验证）
flutter build web --release   # Web 构建（本机已验证）
```

## 10. 质量门禁

```bash
flutter analyze   # 零错误零警告（public_member_api_docs 强制文档）
flutter test      # 117 用例：core 100 + flutter 12 + exports 5
cd example && flutter test   # 4 个集成测试
```

测试组织：`test/core/di|extensions|plugin/`（纯 Dart 单元测试）、`test/flutter/`（widget 测试）、`test/core/no_flutter_imports_test.dart`（分层结构守卫）、`test/exports_test.dart`（桶契约）、`example/test/`（应用级集成测试）。
