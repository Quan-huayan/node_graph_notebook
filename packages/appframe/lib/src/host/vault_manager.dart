/// VaultManager —— Obsidian 式多仓库（M7.3，运行时热切换）。
///
/// 仓库（vault）= 独立数据根目录（结构/内容/外观/脚本/备份全跟随）。
/// 切换 = **重建 HostRuntime + 重装配插件 + 重建 UI 树**（不重启进程）：
/// - 插件已全部经 `servicesProvider` 闭包延迟解析（M7 修正）——
///   新 host 全新装配天然适配；
/// - theme/i18n 是壳层状态（ThemeController/I18nService），显式迁移；
/// - 旧 host post-frame dispose（UI 树已销毁，无悬挂引用）。
///
/// config = `baseDir/vaults.json`（原子写 tmp+rename）；缺省仓库
/// path = baseDir 自身（现有 data/ 零迁移——旧数据原地成为缺省仓库）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:plugon/plugon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'host_runtime.dart';
import 'vault_host.dart';

/// 多仓库管理器 —— `VaultHost` 的文件仓库实现（M8 拆分：契约上移
/// vault_host.dart，本类只保留实现——装配策略经构造注入，更换实现
/// 时壳层/插件零改动）。
class VaultManager extends VaultHost {
  /// 注入基础目录（仓库列表配置文件所在 + 缺省仓库根）、
  /// 插件工厂（每次装配新 host 的全新插件实例）、数据播种器与
  /// 设置持久化（P1-1：透传 HostRuntime，跨仓库切换共享同一 prefs）。
  VaultManager({
    required Directory baseDir,
    required List<Plugin> Function(HostRuntime host) pluginFactory,
    required void Function(HostRuntime host) seed,
    SharedPreferences? prefs,
  }) : _baseDir = baseDir,
       _pluginFactory = pluginFactory,
       _seed = seed,
       _prefs = prefs;

  final Directory _baseDir;
  final List<Plugin> Function(HostRuntime) _pluginFactory;
  final void Function(HostRuntime) _seed;
  final SharedPreferences? _prefs;

  final List<VaultEntry> _vaults = <VaultEntry>[];
  VaultEntry? _current;
  HostRuntime? _host;
  bool _started = false;

  /// 配置文件路径（baseDir/vaults.json）。
  File get _configFile =>
      File('${_baseDir.path}${Platform.pathSeparator}vaults.json');

  @override
  List<VaultEntry> get vaults => List<VaultEntry>.unmodifiable(_vaults);

  @override
  VaultEntry get current {
    final value = _current;
    if (value == null) {
      throw StateError('VaultManager 未启动');
    }
    return value;
  }

  @override
  HostRuntime get host {
    final value = _host;
    if (value == null) {
      throw StateError('VaultManager 未启动');
    }
    return value;
  }

  @override
  bool get started => _started;

  @override
  Future<void> start() async {
    await _loadConfig();
    if (_vaults.isEmpty) {
      // 缺省仓库：baseDir 自身（现有 data/ 零迁移）。
      _vaults.add(VaultEntry(id: 'default', name: '默认仓库', path: _baseDir.path));
    }
    _current ??= _vaults.first;
    await _saveConfig();
    await _ensureRuntime();
    _started = true;
    notifyListeners();
  }

  @override
  Future<void> switchTo(String id) async {
    final target = _vaults.where((v) => v.id == id).firstOrNull;
    if (target == null) {
      throw StateError('仓库不存在: $id');
    }
    if (_current?.id == id) {
      return;
    }
    final old = _host;
    await _ensureRuntime(target);
    _current = target;
    await _saveConfig();
    notifyListeners();
    if (old != null) {
      _disposeLater(old);
    }
  }

  /// post-frame 延迟清理旧 host（UI 树已由键控重建销毁）。
  /// 纯逻辑测试无 WidgetsBinding → 跳过（进程退出自然清理）。
  void _disposeLater(HostRuntime old) {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });
    } catch (_) {
      // 无 binding（flutter test 纯逻辑）——延迟清理无意义。
    }
  }

  @override
  Future<VaultEntry> createVault(String name) async {
    final id = 'vault-${DateTime.now().millisecondsSinceEpoch}';
    final dir = Directory('${_baseDir.path}${Platform.pathSeparator}$id');
    dir.createSync(recursive: true);
    final entry = VaultEntry(id: id, name: name, path: dir.path);
    _vaults.add(entry);
    await switchTo(id);
    return entry;
  }

  /// 移除仓库（守卫：当前不可删 / 默认不可删 / 仅剩不可删）。
  ///
  /// 数据目录**不物理删除**——移入 `<baseDir>/.trash/<id>-<时间戳>/`
  /// 回收站（renameSync 同卷移动；失败即抛异常、数据原地保留），
  /// 误删可手工移回；未来恢复 UI 直接读 .trash 目录。
  @override
  Future<void> removeVault(String id) async {
    if (_current?.id == id) {
      throw StateError('当前仓库不可删除');
    }
    if (_vaults.length <= 1) {
      throw StateError('至少保留一个仓库');
    }
    final target = _vaults.where((v) => v.id == id).firstOrNull;
    if (target == null) {
      return;
    }
    // 默认仓库 = baseDir 自身：内含其余仓库与 vaults.json 配置，
    // 删除（或移动）它会连带摧毁全部仓库——守卫禁止。
    if (target.path == _baseDir.path) {
      throw StateError('默认仓库不可删除');
    }
    _vaults.remove(target);
    await _saveConfig();
    // 移入回收站（数据保留，可找回）。
    final dir = Directory(target.path);
    if (dir.existsSync()) {
      final trashRoot = Directory(
        '${_baseDir.path}${Platform.pathSeparator}.trash',
      );
      trashRoot.createSync(recursive: true);
      final dest =
          '${trashRoot.path}${Platform.pathSeparator}'
          '${target.id}-${DateTime.now().millisecondsSinceEpoch}';
      dir.renameSync(dest);
    }
    notifyListeners();
  }

  /// 读配置（损坏 → 空列表，重建）。
  Future<void> _loadConfig() async {
    if (!_configFile.existsSync()) {
      return;
    }
    try {
      final raw = jsonDecode(await _configFile.readAsString());
      final data = raw is Map<String, dynamic>
          ? raw
          : const <String, dynamic>{};
      final currentId = data['current'] as String?;
      final list = data['vaults'] as List<dynamic>? ?? const <dynamic>[];
      _vaults
        ..clear()
        ..addAll(
          list
              .whereType<Map<String, dynamic>>()
              .map(VaultEntry.fromJson)
              .where((v) => v.id.isNotEmpty && v.path.isNotEmpty),
        );
      _current = _vaults.where((v) => v.id == currentId).firstOrNull;
    } on FormatException {
      _vaults.clear();
      _current = null;
    }
  }

  /// 写配置（原子：tmp + rename）。
  Future<void> _saveConfig() async {
    final data = <String, dynamic>{
      'current': _current?.id,
      'vaults': _vaults.map((v) => v.toJson()).toList(),
    };
    final tmp = File('${_configFile.path}.tmp');
    await tmp.writeAsString(jsonEncode(data));
    await tmp.rename(_configFile.path);
  }

  /// 装配 HostRuntime（数据根 = 仓库路径）+ 播种 + 启动插件。
  Future<void> _ensureRuntime([VaultEntry? entry]) async {
    final target = entry ?? _current!;
    final newHost = HostRuntime(
      dataRoot: Directory(target.path),
      prefs: _prefs,
    );
    // 壳层状态迁移（theme/i18n——旧 host 销毁不丢设置）。
    final old = _host;
    if (old != null) {
      final theme = newHost.themeController
        ..mode = old.themeController.mode
        ..textScale = old.themeController.textScale
        ..fontFamily = old.themeController.fontFamily;
      theme.notifyListeners();
      newHost.i18nService.language = old.i18nService.language;
    }
    // VaultHost 自注册（M8：设置条目/插件经接口解析——可替换实现；
    // 本实例跨 host 共享）。
    newHost.services.addInstance<VaultHost>(this);
    _seed(newHost);
    await newHost.start(
      plugins: _pluginFactory(newHost),
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );
    _host = newHost;
  }
}
