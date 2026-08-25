/// 应用入口（rewrite 架构）——**只组装，零 UI、零行为分发**（强限制，
/// M7 修正 + M8 组合根回调移除）。
///
/// 职责：
/// 1. 创建 HostRuntime（数据根 = 运行目录 data/）
/// 2. 播种示例数据（结构进 Graph，位置进 UIStateStore，投影不变式）
/// 3. 加载插件（servicesProvider 注入——M7 修正模式；模块清单 =
///    组合根本职，插件行为不归组合根）
/// 4. 选择多仓库实现（VaultManager = VaultHost 的文件实现，可替换）
/// 5. runApp(NotebookApp)——应用壳在 appframe；**行为全归壳层服务/
///    插件**（画布 drop 语义 = CanvasCardDropSemantics 服务、Ctrl+N =
///    ToolbarActionRegistry 'note.create' 动作——01 拍板 #32 已反转，
///    M8）。app 顶层不再持有任何插件行为实现。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:plugon/plugon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appframe/appframe.dart';
import 'package:node_ai/node_ai.dart';
import 'package:node_converter/node_converter.dart';
import 'package:node_data_recovery/node_data_recovery.dart';
import 'package:node_editor/node_editor.dart';
import 'package:node_folder/node_folder.dart';
import 'package:node_graph/node_graph.dart';
import 'package:node_i18n/node_i18n.dart';
import 'package:node_lua/node_lua.dart';
import 'package:node_market/node_market.dart';
import 'package:node_search/node_search.dart';
import 'package:node_settings/node_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // P1-1：设置持久化——SharedPreferences 由 app 层提供（拍板 #50），
  // 注入壳层控制器（theme/i18n，经 HostRuntime/VaultManager）与 AI 配置
  // （经 AiPlugin）。重启后主题/语言/AI key 保持（00 §4.2 判据）。
  final prefs = await SharedPreferences.getInstance();
  runZonedGuarded(
    () async {
      final baseDir = Directory(
        '${Directory.current.path}${Platform.pathSeparator}data',
      );
      // 插件工厂（M7.3 多仓库）：每次装配新 host 的全新插件实例——
      // servicesProvider 闭包延迟解析（plugon loadPlugin 每次 dispose
      // 旧 provider，onLoad 快照多插件失效，M7 修正模式）。
      List<Plugin> pluginFactory(HostRuntime host) => <Plugin>[
        FolderPlugin(servicesProvider: () => host.serviceProvider),
        GraphPlugin(servicesProvider: () => host.serviceProvider),
        AiPlugin(servicesProvider: () => host.serviceProvider, prefs: prefs),
        // Lua 动态 Concept 引擎（脚本目录 = 数据根 data/lua_scripts；
        // dll 经 NGN_LUA54_DLL 或应用目录 lua54.dll 提供）。
        LuaPlugin(servicesProvider: () => host.serviceProvider),
        EditorPlugin(servicesProvider: () => host.serviceProvider),
        ConverterPlugin(servicesProvider: () => host.serviceProvider),
        SearchPlugin(),
        I18nPlugin(),
        SettingsPlugin(servicesProvider: () => host.serviceProvider),
        MarketPlugin(servicesProvider: () => host.serviceProvider),
        RecoveryPlugin(servicesProvider: () => host.serviceProvider),
      ];
      // M7.3（Obsidian 式多仓库）：管理器装配缺省仓库（baseDir 自身，
      // 现有 data/ 零迁移）→ 播种 + 启动当前仓库（热切换重建 host）。
      final vaultManager = VaultManager(
        baseDir: baseDir,
        pluginFactory: pluginFactory,
        seed: seedIfEmpty,
        prefs: prefs,
      );
      await vaultManager.start();
      final host = vaultManager.host;
      // 应用壳 = appframe（NotebookApp：MaterialApp + AppShell）——
      // app 包零 UI（强限制），只组装。
      runApp(
        NotebookApp(
          host: host,
          rootNodeId: 'root',
          // 主题控制器（组合根注入，拍板 #39：设置对话框编辑 →
          // MaterialApp 即时响应，M7.2 E3 接线）。
          themeController: host.themeController,
          // M8：多仓库（AppBar 切换器 + 键控整树重建）——经 VaultHost
          // 接口消费（可替换实现）；drop 语义 / Ctrl+N 均不再传回调：
          // 壳层从 CanvasCardDropSemantics 服务与 'note.create' 动作解析。
          vaultManager: vaultManager,
        ),
      );
    },
    (error, stack) {
      debugPrint('═══ Uncaught Error: $error ═══');
      debugPrint('Stack trace: $stack');
    },
  );
}

/// 预置播种（contain 关系模型 + M7 工具栏 UI 节点）。
///
/// **两类预置，两种策略**（M7 修正——旧数据升级）：
/// 1. **基础设施节点**（canvas / aiNode / 工具栏按钮）：**恒补齐**——
///    缺失即功能缺失（画布入口、AI 入口、AppBar 按钮），与用户内容
///    无关，缺失时补（幂等）。
/// 2. **示例内容**（root / folderA / noteB / noteC / contain）：**空库
///    才播种**——root 存在 = 已有数据，不复活用户删除的内容。
///
/// 工具栏按钮 = UI 节点（kind == 'toolbar'，动作 = metadata.action，
/// 由 appframe ToolbarConcept 渲染）。
void seedIfEmpty(HostRuntime host) {
  final graph = host.graph;
  final now = DateTime.now();
  // 基础设施：恒补齐（缺失即补，幂等）。
  final infrastructure = <StoredNode>[
    // 工具栏容器节点（M7.2：00 删除清单"工具栏 = 容器 Node 的 Hook"——
    // ToolbarContainerConcept 结构匹配：kind == toolbar-root，子级 =
    // ToolbarConcept 命中节点自动枚举）。
    StoredNode(
      id: 'toolbar-root',
      title: '工具栏',
      metadata: const <String, dynamic>{'kind': 'toolbar-root'},
      createdAt: now,
      updatedAt: now,
    ),
    // 画布容器节点（CanvasConcept 结构匹配：kind == canvas）。
    StoredNode(
      id: 'canvas',
      title: '画布',
      metadata: const <String, dynamic>{'kind': 'canvas'},
      createdAt: now,
      updatedAt: now,
    ),
    // AI 节点（M7 杀手演示：AIConcept 结构匹配：kind == ai）。
    StoredNode(
      id: 'aiNode',
      title: 'AI 助手',
      metadata: const <String, dynamic>{'kind': 'ai'},
      createdAt: now,
      updatedAt: now,
    ),
    // 工具栏按钮 UI 节点（M7：按钮 = 节点——All is Node；动作 = 插件
    // 注册的 ToolbarActionRegistry 动作）。
    StoredNode(
      id: 'toolbar-canvas',
      title: '管理画布节点',
      metadata: const <String, dynamic>{
        'kind': 'toolbar',
        'icon': 'graphic_eq',
        'tooltip': '管理画布节点',
        'action': 'canvas.manage',
      },
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'toolbar-settings',
      title: '设置',
      metadata: const <String, dynamic>{
        'kind': 'toolbar',
        'icon': 'settings',
        'tooltip': '设置',
        'action': 'settings.open',
      },
      createdAt: now,
      updatedAt: now,
    ),
    // 搜索面板节点（M7.2：搜索在侧边栏 Tab——references.sidebar
    // 指向侧边栏根，SidebarTabsView 枚举，SearchPanelConcept 渲染）。
    StoredNode(
      id: 'search-panel',
      title: '搜索',
      references: const <String, String>{'sidebar': 'root'},
      metadata: const <String, dynamic>{'kind': 'search-panel'},
      createdAt: now,
      updatedAt: now,
    ),
    // 标签面板节点（A2：Obsidian 标签语义——tags-panel 侧边栏 Tab，
    // 与 search-panel 同机制；数据 = TagService 读侧推导）。
    StoredNode(
      id: 'tags-panel',
      title: '标签',
      references: const <String, String>{'sidebar': 'root'},
      metadata: const <String, dynamic>{'kind': 'tags-panel'},
      createdAt: now,
      updatedAt: now,
    ),
    // 最近打开面板节点（C5：Obsidian 最近文件语义——recent-panel 侧边栏
    // Tab；数据 = UIStateStore recent.* 外观键，打开记录由 openNodeDialog
    // 写，删除时键级联清理）。
    StoredNode(
      id: 'recent-panel',
      title: '最近打开',
      references: const <String, String>{'sidebar': 'root'},
      metadata: const <String, dynamic>{'kind': 'recent-panel'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'toolbar-converter',
      title: '导入导出',
      metadata: const <String, dynamic>{
        'kind': 'toolbar',
        'icon': 'import_export',
        'tooltip': '导入导出',
        'action': 'converter.open',
      },
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'toolbar-market',
      title: '插件市场',
      metadata: const <String, dynamic>{
        'kind': 'toolbar',
        'icon': 'storefront',
        'tooltip': '插件市场',
        'action': 'market.open',
      },
      createdAt: now,
      updatedAt: now,
    ),
    // C1：全局图谱按钮（Obsidian Graph view 语义——动作 = 本插件对话框，
    // 命令面板经按钮节点数据驱动自动入列）。
    StoredNode(
      id: 'toolbar-graph-global',
      title: '全局图谱',
      metadata: const <String, dynamic>{
        'kind': 'toolbar',
        'icon': 'hub',
        'tooltip': '全局图谱',
        'action': 'graph.global',
      },
      createdAt: now,
      updatedAt: now,
    ),
    // 设置容器节点（M7.2 阶段 C：SettingsContainerConcept 结构匹配，
    // 子级 = references.settings 反查——各插件自己的设置条目）。
    StoredNode(
      id: 'settings-root',
      title: '设置',
      metadata: const <String, dynamic>{'kind': 'settings-root'},
      createdAt: now,
      updatedAt: now,
    ),
    // 设置条目（M7.2 阶段 C：条目 = 节点，聚合 = 数据引用）：
    // 主题（node_settings）/ AI key（node_ai）/ 语言（node_i18n）。
    StoredNode(
      id: 'settings-theme',
      title: '主题',
      references: const <String, String>{'settings': 'settings-root'},
      metadata: const <String, dynamic>{'kind': 'settings-theme'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'settings-ai',
      title: 'AI 后端',
      references: const <String, String>{'settings': 'settings-root'},
      metadata: const <String, dynamic>{'kind': 'settings-ai'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'settings-i18n',
      title: '语言',
      references: const <String, String>{'settings': 'settings-root'},
      metadata: const <String, dynamic>{'kind': 'settings-i18n'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'settings-appearance',
      title: '外观',
      references: const <String, String>{'settings': 'settings-root'},
      metadata: const <String, dynamic>{'kind': 'settings-appearance'},
      createdAt: now,
      updatedAt: now,
    ),
    // M7.3：多仓库条目（VaultSettingsConcept 结构匹配）。
    StoredNode(
      id: 'settings-vault',
      title: '仓库',
      references: const <String, String>{'settings': 'settings-root'},
      metadata: const <String, dynamic>{'kind': 'settings-vault'},
      createdAt: now,
      updatedAt: now,
    ),
  ];
  for (final preset in infrastructure) {
    if (graph.get(preset.id) == null) {
      graph.save(preset);
    }
  }
  // M7.3 修正：'存储'条目并入'仓库'（多仓库 = 数据目录管理，仓库表单
  // 已展示各仓库路径）——旧数据残留的 settings-storage 节点清理
  // （基础设施节点，非用户内容；幂等）。
  if (graph.get('settings-storage') != null) {
    graph.delete('settings-storage');
  }
  // 示例内容：空库才播种（root 存在 = 已有数据，不复活已删内容）。
  if (graph.get('root') != null) {
    return;
  }
  final presets = <StoredNode>[
    StoredNode(
      id: 'root',
      title: '根目录',
      metadata: const <String, dynamic>{'kind': 'folder'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'folderA',
      title: '我的文件夹',
      metadata: const <String, dynamic>{'kind': 'folder'},
      createdAt: now,
      updatedAt: now,
    ),
    // 包含关系 = contain 实例（L1-node，引用两端）。
    StoredNode(
      id: 'contain-root-folderA',
      title: 'contain:folderA',
      references: const <String, String>{'parent': 'root', 'child': 'folderA'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'noteB',
      title: '第一篇笔记',
      content: '# 第一篇笔记\n\n把这篇笔记拖进左侧的文件夹试试。',
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'noteC',
      title: '第二篇笔记',
      content: '# 第二篇笔记\n\n拖拽 = 创建 contain 关系实例。',
      createdAt: now,
      updatedAt: now,
    ),
  ];
  for (final preset in presets) {
    graph.save(preset);
  }
  // 画布初始位置（判据② 外观存储；缺失才写——不覆盖用户摆放）。
  const positions = <String, Map<String, dynamic>>{
    'noteB': <String, dynamic>{'x': 160, 'y': 140},
    'noteC': <String, dynamic>{'x': 420, 'y': 260},
    'aiNode': <String, dynamic>{'x': 660, 'y': 140},
  };
  for (final entry in positions.entries) {
    if (graph.get(entry.key) != null &&
        host.uiStateStore.get(canvasPositionKey(entry.key)) == null) {
      host.uiStateStore.set(canvasPositionKey(entry.key), entry.value);
    }
  }
}
