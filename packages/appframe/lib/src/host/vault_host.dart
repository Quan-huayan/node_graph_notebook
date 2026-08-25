/// VaultHost —— 多仓库宿主契约（M8：可替换仓库框架的抽象边界）。
///
/// 背景（01 拍板 #31/#32 链式纠正）：旧 VaultManager 把三件事捆成一个
/// 具体类——① 壳层/插件消费的契约（current/host/switchTo…）、② 装配
/// 策略（pluginFactory + seed + prefs + HostRuntime 构造）、③ 文件实现
/// （vaults.json 原子写 / 默认仓库 / .trash 回收站）。换仓库框架 = 重写
/// 类 + 重接 app。M8 拆分：**壳层与插件只消费本接口**（类型安全、可
/// 替换），VaultManager 只是其中一个实现（文件仓库）。
///
/// 可替换性：git 仓库 / 云同步 / 配置异地化 = 新建本接口的实现，
/// app 装配点只换实现类，壳层/插件零改动。
library;

import 'package:flutter/foundation.dart';

import 'host_runtime.dart';

/// 仓库条目。
class VaultEntry {
  /// 构造仓库条目。
  const VaultEntry({required this.id, required this.name, required this.path});

  /// 反序列化（容错：缺字段 → 空串兜底）。
  factory VaultEntry.fromJson(Map<String, dynamic> json) => VaultEntry(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    path: json['path'] as String? ?? '',
  );

  /// 仓库 id（配置文件主键）。
  final String id;

  /// 仓库显示名。
  final String name;

  /// 数据根目录绝对路径。
  final String path;

  /// JSON 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'path': path,
  };
}

/// 多仓库宿主契约（ChangeNotifier——切换通知壳层整树重建）。
abstract class VaultHost extends ChangeNotifier {
  /// 仓库列表。
  List<VaultEntry> get vaults;

  /// 当前仓库。
  VaultEntry get current;

  /// 当前仓库的 HostRuntime（热切换后为新装配实例）。
  HostRuntime get host;

  /// 已启动。
  bool get started;

  /// 启动（读配置 → 装配当前仓库）。
  Future<void> start();

  /// 热切换仓库（新 host 装配 → 状态迁移 → 替换 → 旧 host 延迟清理）。
  Future<void> switchTo(String id);

  /// 创建仓库（建数据目录 + 条目 + 切换）。
  Future<VaultEntry> createVault(String name);

  /// 移除仓库（守卫 + 数据移入回收站，可找回）。
  Future<void> removeVault(String id);
}